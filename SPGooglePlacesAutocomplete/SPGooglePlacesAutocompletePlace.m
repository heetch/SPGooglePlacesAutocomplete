//
//  SPGooglePlacesAutocompletePlace.m
//  SPGooglePlacesAutocomplete
//
//  Created by Stephen Poletto on 7/17/12.
//  Copyright (c) 2012 Stephen Poletto. All rights reserved.
//

#import "SPGooglePlacesAutocompletePlace.h"
#import "SPGooglePlacesPlaceDetailQuery.h"

@interface SPGooglePlacesAutocompletePlace()
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *reference;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic) SPGooglePlacesAutocompletePlaceType type;
@end

@implementation SPGooglePlacesAutocompletePlace

+ (SPGooglePlacesAutocompletePlace *)placeFromDictionary:(NSDictionary *)placeDictionary apiKey:(NSString *)apiKey
{
    SPGooglePlacesAutocompletePlace *place = [[self alloc] init];
    place.name = placeDictionary[@"description"];
    place.reference = placeDictionary[@"reference"];
    place.identifier = placeDictionary[@"id"];
    place.type = SPPlaceTypeFromDictionary(placeDictionary);
    place.key = apiKey;
    return place;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Name: %@, Reference: %@, Identifier: %@, Type: %@",
            self.name, self.reference, self.identifier, SPPlaceTypeStringForPlaceType(self.type)];
}

- (CLGeocoder *)geocoder {
    if (!geocoder) {
        geocoder = [[CLGeocoder alloc] init];
    }
    return geocoder;
}

- (void)resolveEstablishmentPlaceToPlacemark:(SPGooglePlacesPlacemarkResultBlock)block {
    SPGooglePlacesPlaceDetailQuery *query = [[SPGooglePlacesPlaceDetailQuery alloc] initWithApiKey:self.key];
    query.reference = self.reference;
    [query fetchPlaceDetail:^(NSDictionary *placeDictionary, NSError *error) {
        if (error) {
            block(nil, nil, error);
        } else {
            // Create palcemark from coordinates
            if ([placeDictionary objectForKey:@"geometry"]) {
                NSDictionary *locationDictionnary = [[placeDictionary objectForKey:@"geometry"] objectForKey:@"location"];
                CLLocation *location;

                if ([locationDictionnary objectForKey:@"lat"] && [locationDictionnary objectForKey:@"lng"]) {
                    CGFloat latitude = 360.0f;
                    CGFloat longitude = 360.0f;

                    if ([locationDictionnary objectForKey:@"lat"]) {
                        latitude = [[locationDictionnary objectForKey:@"lat"] floatValue];
                    }

                    if ([locationDictionnary objectForKey:@"lng"]) {
                        longitude = [[locationDictionnary objectForKey:@"lng"] floatValue];
                    }

                    location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
                }

                [[self geocoder] reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
                    if (error) {
                        block(nil, nil, error);
                    }
                    else {
                        CLPlacemark *placemark = [placemarks onlyObject];
                        block(placemark, self.name, error);
                    }
                }];
            }
            else {
                // use geocoder
                NSString *addressString = placeDictionary[@"formatted_address"];
                [[self geocoder] geocodeAddressString:addressString completionHandler:^(NSArray *placemarks, NSError *error) {
                    if (error) {
                        block(nil, nil, error);
                    } else {
                        CLPlacemark *placemark = [placemarks onlyObject];
                        block(placemark, self.name, error);
                    }
                }];
            }
        }
    }];
}

- (void)resolveGecodePlaceToPlacemark:(SPGooglePlacesPlacemarkResultBlock)block {
    [[self geocoder] geocodeAddressString:self.name completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error) {
            block(nil, nil, error);
        } else {
            CLPlacemark *placemark = [placemarks onlyObject];
            block(placemark, self.name, error);
        }
    }];
}

- (void)resolveToPlacemark:(SPGooglePlacesPlacemarkResultBlock)block {
    if (self.type == SPPlaceTypeGeocode) {
        // Geocode places already have their address stored in the 'name' field.
        [self resolveGecodePlaceToPlacemark:block];
    } else {
        [self resolveEstablishmentPlaceToPlacemark:block];
    }
}


@end
