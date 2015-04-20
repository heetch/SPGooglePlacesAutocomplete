//
//  SPGooglePlacesAutocompleteQuery.m
//  SPGooglePlacesAutocomplete
//
//  Created by Stephen Poletto on 7/17/12.
//  Copyright (c) 2012 Stephen Poletto. All rights reserved.
//

#import <MapKit/MapKit.h>

#import "SPGooglePlacesAutocompleteQuery.h"
#import "SPGooglePlacesAutocompletePlace.h"

static const float kMinWithAppleMaps = 0.0f;

@interface SPGooglePlacesAutocompleteQuery()

@property (nonatomic, copy) SPGooglePlacesAutocompleteResultBlock resultBlock;
@property (nonatomic, strong, readwrite) NSTimer *appleMapsTimer;
@property (nonatomic, readwrite) BOOL shouldUseAppleMaps;

@end

@implementation SPGooglePlacesAutocompleteQuery

- (id)initWithApiKey:(NSString *)apiKey {
    self = [super init];
    if (self) {
        // Setup default property values.
        self.sensor = YES;
        self.key = apiKey;
        self.offset = NSNotFound;
        self.location = CLLocationCoordinate2DMake(-1, -1);
        self.radius = 500;
        self.types = SPPlaceTypeInvalid;
        self.appleMapsTimer = nil;
        self.shouldUseAppleMaps = NO;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Query URL: %@", [self googleURLString]];
}


- (NSString *)googleURLString {
    NSMutableString *url = [NSMutableString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%@&sensor=%@&key=%@",
                            [self.input stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                            SPBooleanStringForBool(self.sensor), self.key];
    if (self.offset != NSNotFound) {
        [url appendFormat:@"&offset=%lu", (unsigned long)self.offset];
    }
    if (self.location.latitude != -1) {
        [url appendFormat:@"&location=%f,%f", self.location.latitude, self.location.longitude];
    }
    if (self.radius != NSNotFound) {
        [url appendFormat:@"&radius=%f", self.radius];
    }
    if (self.language) {
        [url appendFormat:@"&language=%@", self.language];
    }
    if (self.types != SPPlaceTypeInvalid) {
        [url appendFormat:@"&types=%@", SPPlaceTypeStringForPlaceType(self.types)];
    }
    return url;
}

- (void)cleanup {
    googleConnection = nil;
    responseData = nil;
    self.resultBlock = nil;
}

- (void)cancelOutstandingRequests {
    [googleConnection cancel];
    [self cleanup];
}

- (void)fetchPlaces:(SPGooglePlacesAutocompleteResultBlock)block {
    if (!self.key) {
        return;
    }
    
    if (SPIsEmptyString(self.input)) {
        // Empty input string. Don't even bother hitting Google.
        block(@[], nil);
        return;
    }
    
    [self cancelOutstandingRequests];
    self.resultBlock = block;

    if (self.shouldUseAppleMaps == NO) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[self googleURLString]]];
        googleConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        responseData = [[NSMutableData alloc] init];
    } else {
        MKLocalSearchRequest *searchRequest = [[MKLocalSearchRequest alloc] init];
        [searchRequest setNaturalLanguageQuery:self.input];

        if ((self.location.latitude != -1) &&
            (self.location.longitude != -1)) {
            MKCoordinateRegion locationRegion = MKCoordinateRegionMakeWithDistance(self.location, self.radius, self.radius);
            [searchRequest setRegion:locationRegion];
        }
        MKLocalSearch *localSearch = [[MKLocalSearch alloc] initWithRequest:searchRequest];
        [localSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
            if (!error) {
                NSMutableArray *parsedPlaces = [NSMutableArray array];

                for (MKMapItem *mapItem in [response mapItems]) {
                    [parsedPlaces addObject:[SPGooglePlacesAutocompletePlace placeFromMKMapItem:mapItem apiKey:self.key]];
                }
                self.resultBlock(parsedPlaces, nil);
            } else {
                self.resultBlock(nil, error);
            }
        }];
    }
}

#pragma mark -
#pragma mark NSURLConnection Delegate

- (void)failWithError:(NSError *)error {
    if (self.resultBlock != nil) {
        self.resultBlock(nil, error);
    }
    [self cleanup];
}

- (void)succeedWithPlaces:(NSArray *)places {
    NSMutableArray *parsedPlaces = [NSMutableArray array];
    for (NSDictionary *place in places) {
        [parsedPlaces addObject:[SPGooglePlacesAutocompletePlace placeFromDictionary:place apiKey:self.key]];
    }
    if (self.resultBlock != nil) {
        self.resultBlock(parsedPlaces, nil);
    }
    [self cleanup];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (connection == googleConnection) {
        [responseData setLength:0];
    }
}

- (void)connection:(NSURLConnection *)connnection didReceiveData:(NSData *)data {
    if (connnection == googleConnection) {
        [responseData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (connection == googleConnection) {
        [self failWithError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (connection == googleConnection) {
        NSError *error = nil;
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];
        if (error) {
            [self failWithError:error];
        } else if ([response[@"status"] isEqualToString:@"ZERO_RESULTS"]) {
            [self succeedWithPlaces:@[]];
        } else if ([response[@"status"] isEqualToString:@"OK"]) {
            [self succeedWithPlaces:response[@"predictions"]];
        } else if ([response[@"status"] isEqualToString:@"OVER_QUERY_LIMIT"] || [response[@"status"] isEqualToString:@"REQUEST_DENIED"] || [response[@"status"] isEqualToString:@"INVALID_REQUEST"]) {
            [self switchToApplePlaces];
            [self fetchPlaces:self.resultBlock];
        } else {
            // Failed with unknown error.
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: response[@"status"]};
            [self failWithError:[NSError errorWithDomain:@"com.spoletto.googleplaces" code:kGoogleAPINSErrorCode userInfo:userInfo]];
        }
    }
}

#pragma mark - Apple Maps switch

- (void)switchToApplePlaces {
    self.appleMapsTimer = [NSTimer scheduledTimerWithTimeInterval:(kMinWithAppleMaps * 60.0)
                                                           target:self
                                                         selector:@selector(switchToGooglePlaces:)
                                                         userInfo:nil
                                                          repeats:NO];
    self.shouldUseAppleMaps = YES;
}

- (void)switchToGooglePlaces:(id)sender {
    [self.appleMapsTimer invalidate]; self.appleMapsTimer = nil;
    self.shouldUseAppleMaps = NO;
}

@end