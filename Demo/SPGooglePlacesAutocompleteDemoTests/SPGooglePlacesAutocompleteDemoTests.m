#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

#import "SPGooglePlacesAutocompleteQuery.h"




@interface SPGooglePlacesAutocompleteQuery ()
@property (nonatomic, readwrite) BOOL shouldUseAppleMaps;
@end

@interface SPGooglePlacesAutocompleteQueryTests : XCTestCase

@property (nonatomic, strong, readwrite) SPGooglePlacesAutocompleteQuery *qry;

@end

@implementation SPGooglePlacesAutocompleteQueryTests

- (void)setUp {
    [super setUp];
    self.qry = [[SPGooglePlacesAutocompleteQuery alloc] initWithApiKey:@"AIzaSyAFsaDn7vyI8pS53zBgYRxu0HfRwYqH-9E"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.qry = nil;
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

- (void)testResults {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"maps.googleapis.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {

        NSDictionary *response = @{
                                   @"predictions" :
                                       @[
                                           @{
                                               @"description" : @"Paris, France",
                                               @"id" : @"691b237b0322f28988f3ce03e321ff72a12167fd",
                                               @"matched_substrings" :
                                                   @{
                                                       @"length" : [[NSNumber alloc] initWithInt:2],
                                                       @"offset" : [[NSNumber alloc] initWithInt:0]
                                                       },
                                               @"place_id" : @"ChIJD7fiBh9u5kcRYJSMaMOCCwQ",
                                               @"reference" : @"ClRPAAAAOV6o5AANjB6uMv1YPsyTyOliJvOW0kkm_jBOUiEDgzK7lmn1hvOVY0mZQzoV7nC5OcU8aKPhTRlmMDHFg1FUklX7b5AqPcowTx8qNYqnNAMSEDr56BSrORjB1fhKFBAKsuEaFAZfh-DqFAlnvI20BYNWnQ2mfldO",
                                               @"terms" :
                                                   @[@{
                                                         @"offset" : [[NSNumber alloc] initWithInt:0],
                                                         @"value" : @"Paris",
                                                         },
                                                     @{
                                                         @"offset" : [[NSNumber alloc] initWithInt:7],
                                                         @"value" : @"France",
                                                         }],
                                               @"types" :
                                                   @[@"locality", @"political", @"geocode"],
                                               },
                                           @{
                                               @"description" : @"Paris, France",
                                               @"id" : @"691b237b0322f28988f3ce03e321ff72a12167fd",
                                               @"matched_substrings" :
                                                   @{
                                                       @"length" : [[NSNumber alloc] initWithInt:2],
                                                       @"offset" : [[NSNumber alloc] initWithInt:0]
                                                       },
                                               @"place_id" : @"ChIJD7fiBh9u5kcRYJSMaMOCCwQ",
                                               @"reference" : @"ClRPAAAAOV6o5AANjB6uMv1YPsyTyOliJvOW0kkm_jBOUiEDgzK7lmn1hvOVY0mZQzoV7nC5OcU8aKPhTRlmMDHFg1FUklX7b5AqPcowTx8qNYqnNAMSEDr56BSrORjB1fhKFBAKsuEaFAZfh-DqFAlnvI20BYNWnQ2mfldO",
                                               @"terms" :
                                                   @[@{
                                                         @"offset" : [[NSNumber alloc] initWithInt:0],
                                                         @"value" : @"Paris",
                                                         },
                                                     @{
                                                         @"offset" : [[NSNumber alloc] initWithInt:7],
                                                         @"value" : @"France",
                                                         }],
                                               @"types" :
                                                   @[@"locality", @"political", @"geocode"],
                                               }
                                           ],
                                   @"status" : @"OK"
    };
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];


    self.qry.input = @"Paris";
    XCTestExpectation *expectation = [self expectationWithDescription:@"PlacesSearchs"];
    [self.qry fetchPlaces:^(NSArray *places, NSError *error) {
        XCTAssertEqual([places count], 2);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void) testNoResults {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"maps.googleapis.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{
                                   @"status" : @"ZERO_RESULTS"
                                   };
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];


    self.qry.input = @"Paris";
    XCTestExpectation *expectation = [self expectationWithDescription:@"PlacesSearchs"];
    [self.qry fetchPlaces:^(NSArray *places, NSError *error) {
        XCTAssertEqual([places count], 0);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void)testRequestDenied {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"maps.googleapis.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{
                                   @"status" : @"REQUEST_DENIED"
                                   };
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];


    self.qry.input = @"Paris";
    XCTestExpectation *expectation = [self expectationWithDescription:@"PlacesSearchs"];
    [self.qry fetchPlaces:^(NSArray *places, NSError *error) {
        XCTAssertNotEqual([places count], 0);
        XCTAssertNil(error);
        XCTAssertTrue(self.qry.shouldUseAppleMaps);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:40.0 handler:nil];
}

- (void)testOVER_QUERY_LIMIT {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"maps.googleapis.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{
                                   @"status" : @"OVER_QUERY_LIMIT"
                                   };
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];

    self.qry.input = @"Paris";
    XCTestExpectation *expectation = [self expectationWithDescription:@"PlacesSearchs"];
    [self.qry fetchPlaces:^(NSArray *places, NSError *error) {
        XCTAssertNotEqual([places count], 0);
        XCTAssertNil(error);
        XCTAssertTrue(self.qry.shouldUseAppleMaps);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:40.0 handler:nil];

}

@end

