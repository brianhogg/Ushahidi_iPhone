/*****************************************************************************
 ** Copyright (c) 2010 Ushahidi Inc
 ** All rights reserved
 ** Contact: team@ushahidi.com
 ** Website: http://www.ushahidi.com
 **
 ** GNU Lesser General Public License Usage
 ** This file may be used under the terms of the GNU Lesser
 ** General Public License version 3 as published by the Free Software
 ** Foundation and appearing in the file LICENSE.LGPL included in the
 ** packaging of this file. Please review the following information to
 ** ensure the GNU Lesser General Public License version 3 requirements
 ** will be met: http://www.gnu.org/licenses/lgpl.html.
 **
 **
 ** If you have questions regarding the use of this file, please contact
 ** Ushahidi developers at team@ushahidi.com.
 **
 *****************************************************************************/

#import "Ushahidi.h"
#import "SynthesizeSingleton.h"
#import "NSKeyedArchiver+Extension.h"
#import "NSKeyedUnarchiver+Extension.h"
#import "NSString+Extension.h"
#import "NSObject+Extension.h"
#import "NSError+Extension.h"
#import "NSURL+Extension.h"
#import "NSDictionary+Extension.h"
#import "ASIHTTPRequest+Extension.h"
#import "JSON.h"
#import "Deployment.h"
#import "Category.h"
#import "Location.h"
#import "Incident.h"
#import "Photo.h"
#import "News.h"
#import "Sound.h"
#import "Video.h"
#import "Settings.h"
#import "Incident.h"
#import "Checkin.h"
#import "Internet.h"
#import "Device.h"
#import "User.h"

@interface Ushahidi ()

@property(nonatomic, retain) Deployment *deployment;
@property(nonatomic, retain) NSMutableDictionary *maps;
@property(nonatomic, retain) NSMutableDictionary *deployments;
@property(nonatomic, retain) NSOperationQueue *mainQueue;
@property(nonatomic, retain) NSOperationQueue *mapQueue;
@property(nonatomic, retain) NSOperationQueue *photoQueue;
@property(nonatomic, retain) NSOperationQueue *uploadQueue;
@property(nonatomic, retain) NSString *mapDistance;

- (ASIHTTPRequest *) queueAsynchronousRequest:(NSString *)url 
								  forDelegate:(id<UshahidiDelegate>)delegate 
								startSelector:(SEL)startSelector
							   finishSelector:(SEL)finishSelector
								 failSelector:(SEL)failSelector;

- (ASIFormDataRequest *) getAsynchronousPost:(NSString *)url 
								 forDelegate:(id<UshahidiDelegate>)delegate
							   startSelector:(SEL)startSelector
							  finishSelector:(SEL)finishSelector
								failSelector:(SEL)failSelector;

- (void) uploadIncidentStarted:(ASIHTTPRequest *)request;
- (void) uploadIncidentFinished:(ASIHTTPRequest *)request;
- (void) uploadIncidentFailed:(ASIHTTPRequest *)request;

- (void) uploadCheckinStarted:(ASIHTTPRequest *)request;
- (void) uploadCheckinFinished:(ASIHTTPRequest *)request;
- (void) uploadCheckinFailed:(ASIHTTPRequest *)request;

- (void) getMapsStarted:(ASIHTTPRequest *)request;
- (void) getMapsFinished:(ASIHTTPRequest *)request;
- (void) getMapsFailed:(ASIHTTPRequest *)request;

- (void) getIncidentsStarted:(ASIHTTPRequest *)request;
- (void) getIncidentsFinished:(ASIHTTPRequest *)request;
- (void) getIncidentsFailed:(ASIHTTPRequest *)request;

- (void) getCategoriesStarted:(ASIHTTPRequest *)request;
- (void) getCategoriesFinished:(ASIHTTPRequest *)request;
- (void) getCategoriesFailed:(ASIHTTPRequest *)request;

- (void) getLocationsStarted:(ASIHTTPRequest *)request;
- (void) getLocationsFinished:(ASIHTTPRequest *)request;
- (void) getLocationsFailed:(ASIHTTPRequest *)request;

- (void) downloadPhotoStarted:(ASIHTTPRequest *)request;
- (void) downloadPhotoFinished:(ASIHTTPRequest *)request;
- (void) downloadPhotoFailed:(ASIHTTPRequest *)request;

- (void) downloadMap:(Incident *)incident forDelegate:(id<UshahidiDelegate>)delegate;
- (void) downloadMapFinished:(ASIHTTPRequest *)request;
- (void) downloadMapFailed:(ASIHTTPRequest *)request;

- (void) getCheckinsStarted:(ASIHTTPRequest *)request;
- (void) getCheckinsFinished:(ASIHTTPRequest *)request;
- (void) getCheckinsFailed:(ASIHTTPRequest *)request;

- (BOOL) isDuplicate:(Incident *)incident;

- (void) loadDeployment:(Deployment *)theDeployment;
- (void) loadDeploymentInBackground:(Deployment *)theDeployment;

@end

@implementation Ushahidi

@synthesize maps, deployments, deployment, mapDistance;
@synthesize mainQueue, mapQueue, photoQueue, uploadQueue;

typedef enum {
	MediaTypeUnkown = 0,
	MediaTypePhoto = 1,
	MediaTypeVideo = 2,
	MediaTypeSound = 3,
	MediaTypeNews = 4
} MediaType;

NSString * const kGoogleStaticMaps = @"http://maps.google.com/maps/api/staticmap";
NSInteger const kGoogleOverCapacitySize = 100;

SYNTHESIZE_SINGLETON_FOR_CLASS(Ushahidi);

- (id) init {
	DLog(@"");
	if ((self = [super init])) {
		self.deployments = [NSKeyedUnarchiver unarchiveObjectWithKey:@"deployments"];
		if (self.deployments == nil) self.deployments = [[NSMutableDictionary alloc] init];
		
		self.mainQueue = [[NSOperationQueue alloc] init];
		[self.mainQueue setMaxConcurrentOperationCount:1];
		[self.mainQueue addObserver:self forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:nil];
		
		self.uploadQueue = [[NSOperationQueue alloc] init];
		[self.uploadQueue setMaxConcurrentOperationCount:1];
		[self.uploadQueue addObserver:self forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:nil];
		
		self.mapQueue = [[NSOperationQueue alloc] init];
		[self.mapQueue setMaxConcurrentOperationCount:1];
		[self.mapQueue addObserver:self forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:nil];
		
		self.photoQueue = [[NSOperationQueue alloc] init];
		[self.photoQueue setMaxConcurrentOperationCount:1];
		[self.photoQueue addObserver:self forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:nil];
	}
	return self;
}

- (void)dealloc {
	DLog(@"");
	[maps release];
	[deployment release];
	[deployments release];
	[mainQueue release];
	[mapQueue release];
	[photoQueue release];
	[uploadQueue release];
	[mapDistance release];
	[super dealloc];
}

#pragma mark -
#pragma mark Archive

- (void) archive {
	DLog(@"");
	if (self.deployment != nil) {
		[self.deployment archive];
	}
	[NSKeyedArchiver archiveObject:self.deployments forKey:@"deployments"];
	if (self.maps != nil) {
		[NSKeyedArchiver archiveObject:self.maps forKey:@"maps"];
	}
}

- (void) loadDeployment:(Deployment *)theDeployment inBackground:(BOOL)inBackground {
	if (inBackground) {
		[self performSelectorInBackground:@selector(loadDeploymentInBackground:) withObject:theDeployment];
	}
	else {
		[self loadDeployment:theDeployment];
	}
}

- (void) loadDeployment:(Deployment *)theDeployment {
	DLog(@"%@", [theDeployment domain]);
	if (self.deployment != nil) {
		[self.deployment archive];
		[self.deployment purge];
	}
	if (theDeployment != nil) {
		[theDeployment unarchive];	
		[[Settings sharedSettings] setLastDeployment:theDeployment.url];
		self.deployment = theDeployment;
	}
	else {
		[[Settings sharedSettings] setLastDeployment:nil];
		self.deployment = nil;
	}
	[[Settings sharedSettings] save];
}

- (void) loadDeploymentInBackground:(Deployment *)theDeployment {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[self loadDeployment:theDeployment];
	[pool release];
}

#pragma mark -
#pragma mark Deployments

- (NSString *) deploymentName {
	return self.deployment != nil ? self.deployment.name : nil;
}

- (BOOL)addDeployment:(Deployment *)theDeployment {
	if (theDeployment != nil) {
		[self.deployments setObject:theDeployment forKey:theDeployment.url];
		if ([[NSFileManager defaultManager] fileExistsAtPath:[theDeployment archiveFolder]] == NO) {
			NSError *error = nil;
			BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:[theDeployment archiveFolder] 
													 withIntermediateDirectories:YES 
																	  attributes:nil 
																		   error:&error];
			if (!success || error) {
				DLog(@"Add Directory Error: %@", [error localizedDescription]);
				return NO;
			}
		}
		return YES;
	}
	return NO;
}

- (BOOL)addDeploymentByName:(NSString *)name andUrl:(NSString *)url {
	if (name != nil && [name length] > 0 && url != nil && [url length] > 0) {
		Deployment *theDeployment = [[Deployment alloc] initWithName:name url:url];
		[self.deployments setObject:theDeployment forKey:url];
		if ([[NSFileManager defaultManager] fileExistsAtPath:[theDeployment archiveFolder]] == NO) {
			NSError *error = nil;
			BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:[theDeployment archiveFolder] 
													 withIntermediateDirectories:YES 
																	  attributes:nil 
																		   error:&error];
			if (!success || error) {
				DLog(@"Add Directory Error: %@", [error localizedDescription]);
				return NO;
			}
		}
		return YES;
	}
	return NO;
}

- (BOOL)removeDeployment:(Deployment *)theDeployment {
	if (theDeployment != nil) {
		[self.deployments removeObjectForKey:theDeployment.url];
		if ([[NSFileManager defaultManager] fileExistsAtPath:[theDeployment archiveFolder]]) {
			NSError *error = nil;
			for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[theDeployment archiveFolder] error:&error]) {
				NSString *filePath = [[theDeployment archiveFolder] stringByAppendingPathComponent:file];
				DLog(@"Deleting %@", filePath);
				BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
				if (!success || error) {
					DLog(@"Remove Directory Error: %@", [error localizedDescription]);
					return NO;
				}
			}
		}
		return YES;
	}
	return NO;
}

- (Deployment *) getDeploymentWithUrl:(NSString *)url {
	return [self.deployments objectForKey:url];
}

- (NSArray *) getDeploymentsUsingSorter:(SEL)sorter {
	if ([self.deployments count] == 0) {
		[self addDeploymentByName:NSLocalizedString(@"Ushahidi Demo", nil) andUrl:@"http://demo.ushahidi.com"];
	}
	return [[self.deployments allValues] sortedArrayUsingSelector:sorter];
}

#pragma mark -
#pragma mark Maps

- (NSArray *) getMaps {
	if (self.maps == nil) {
		self.maps = [NSKeyedUnarchiver unarchiveObjectWithKey:@"maps"];
		if (self.maps == nil) self.maps = [[NSMutableDictionary alloc] init];
	}
	return [self.maps allValues];
}

- (NSArray *) getMapsForDelegate:(id<UshahidiDelegate>)delegate latitude:(NSString *)latitude longitude:(NSString *)longitude distance:(NSString *)distance {
	if (self.maps == nil) {
		self.maps = [NSKeyedUnarchiver unarchiveObjectWithKey:@"maps"];
		if (self.maps == nil) self.maps = [[NSMutableDictionary alloc] init];
	}
	self.mapDistance = distance;
	NSMutableString *url = [NSMutableString stringWithFormat:@"http://tracker.ushahidi.com/list/?return_vars=url,name,description,discovery_date"];
	if ([NSString isNilOrEmpty:latitude] == NO && [NSString isNilOrEmpty:longitude] == NO) {
		[url appendFormat:@"&lat=%@", latitude];
		[url appendFormat:@"&lon=%@", longitude];
		if ([NSString isNilOrEmpty:distance] == NO) {
			[url appendFormat:@"&distance=%@", distance];
		}
		else {
			[url appendFormat:@"&distance=500"];
		}
		[url appendFormat:@"&units=km"];
	}
	[self queueAsynchronousRequest:url 
					   forDelegate:delegate
					 startSelector:@selector(getMapsStarted:)
					finishSelector:@selector(getMapsFinished:)
					  failSelector:@selector(getMapsFailed:)];
	return [self.maps allValues];
}

- (void) getMapsStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
}

- (void) getMapsFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	SEL callback = @selector(downloadedFromUshahidi:maps:error:hasChanges:);
	if ([request responseStatusCode] != HttpStatusOK) {
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:callback
						target:delegate 
					   objects:self, [self.maps allValues], error, nil];
	}
	else {
		NSDictionary *json = [[request responseString] JSONValue];
		if (json != nil) {
			if([self.mapDistance isEqualToString:[[Settings sharedSettings] mapDistance]] == NO) {
				[[Settings sharedSettings] setMapDistance:self.mapDistance];
				[self.maps removeAllObjects];
			}
			BOOL hasChanges = NO;
			for (NSDictionary *dictionary in [json allValues]) {
				NSString *url = [dictionary stringForKey:@"url"];
				if ([self.maps count] == 0 || [self.maps objectForKey:url] == nil) {
					NSString *name = [dictionary stringForKey:@"name"];
					if ([NSString isNilOrEmpty:name] == NO) {
						Deployment *map = [[Deployment alloc] initWithDictionary:dictionary];
						[self.maps setObject:map forKey:url];
						[map release];
						hasChanges = YES;	
					}
				}
			}
			[self dispatchSelector:callback 
							target:delegate 
						   objects:self, [self.maps allValues], nil, hasChanges, nil];
		}
		else {
			DLog(@"RESPONSE: %@", [request responseString]);
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:[request responseStatusCode] 
											  message:[request responseStatusMessage]];
			[self dispatchSelector:callback 
							target:delegate 
						   objects:self, [self.maps allValues], error, NO, nil];
		}
	}
}

- (void) getMapsFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	DLog(@"RESPONSE: %@", [request responseString]);
	[self dispatchSelector:@selector(downloadedFromUshahidi:maps:error:hasChanges:) 
					target:[request getDelegate] 
				   objects:self, [self.maps allValues], [request error], NO, nil];
}

#pragma mark -
#pragma mark Users

- (BOOL) hasUsers {
	return [self.deployment users] != nil;
}

- (NSArray *) getUsers {
	return [[self.deployment users] allValues];
}

#pragma mark -
#pragma mark Checkins

- (BOOL) deploymentSupportsCheckins {
	return [self.deployment supportsCheckins];
}

- (NSArray *) getCheckinsForDelegate:(id<UshahidiDelegate>)delegate {
	[self queueAsynchronousRequest:[self.deployment getCheckins] 
					   forDelegate:delegate
					 startSelector:@selector(getCheckinsStarted:)
					finishSelector:@selector(getCheckinsFinished:)
					  failSelector:@selector(getCheckinsFailed:)];
	return [self.deployment.checkins allValues];
}

- (void) getCheckinsStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
}

- (void) getCheckinsFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	if ([request responseStatusCode] != HttpStatusOK) {
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:@selector(downloadedFromUshahidi:checkins:error:hasChanges:)
						target:[request getDelegate] 
					   objects:self, [self.deployment.checkins allValues], error, nil];
	}
	else {
		NSDictionary *json = [[request responseString] JSONValue];
		if (json == nil) {
			DLog(@"RESPONSE: %@", [request responseString]);
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:HttpStatusInternalServerError 
											  message:NSLocalizedString(@"Unable To Download Checkins", nil)];
			[self dispatchSelector:@selector(downloadedFromUshahidi:checkins:error:hasChanges:)
							target:[request getDelegate] 
						   objects:self, [self.deployment.checkins allValues], error, NO, nil];
		}
		else {
			NSDictionary *payload = [json objectForKey:@"payload"];
			if (payload != nil) {
				BOOL hasCheckinChanges = NO;
				NSArray *checkins = [payload objectForKey:@"checkins"]; 
				for (NSDictionary *dictionary in checkins) {
					Checkin *checkin = [[Checkin alloc] initWithDictionary:dictionary];
					if ([self.deployment.checkins objectForKey:checkin.identifier] == nil) {
						[self.deployment.checkins setObject:checkin forKey:checkin.identifier];
						hasCheckinChanges = YES;
						DLog(@"CHECKIN: %@", dictionary);
					}
					[checkin release];
				}
				if (hasCheckinChanges) {
					DLog(@"Has New Checkins");
				}
				[self dispatchSelector:@selector(downloadedFromUshahidi:checkins:error:hasChanges:)
								target:[request getDelegate]
							   objects:self, [self.deployment.checkins allValues], nil, hasCheckinChanges, nil];
				
				BOOL hasUserChanges = NO;
				NSArray *users = [payload objectForKey:@"users"]; 
				for (NSDictionary *dictionary in users) {
					User *user = [[User alloc] initWithDictionary:dictionary];
					if ([self.deployment.users objectForKey:user.identifier] == nil) {
						if ([user name] != nil && [[user name] isEqualToString:@"Not Fully Registered Checkin User"] == NO) {
							[self.deployment.users setObject:user forKey:user.identifier];
							hasUserChanges = YES;
							DLog(@"USER: %@", dictionary);
						}
					}
					[user release];
				}
				if (hasCheckinChanges) {
					DLog(@"Has New Users");
				}
				[self dispatchSelector:@selector(downloadedFromUshahidi:users:hasChanges:)
								target:[request getDelegate] 
							   objects:self, [self.deployment.users allValues], hasUserChanges, nil];
			}
			else {
				NSError *error = [NSError errorWithDomain:self.deployment.domain 
													 code:HttpStatusInternalServerError 
												  message:NSLocalizedString(@"Unable To Download Checkins", nil)];
				[self dispatchSelector:@selector(downloadedFromUshahidi:checkins:error:hasChanges:)
								target:[request getDelegate] 
							   objects:self, [self.deployment.checkins allValues], error, NO, nil];
			}
		}
	}
}

- (void) getCheckinsFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	DLog(@"RESPONSE: %@", [request responseString]);
	[self dispatchSelector:@selector(downloadedFromUshahidi:checkins:error:hasChanges:) 
					target:[request getDelegate] 
				   objects:self, [self.deployment.checkins allValues], [request error], NO, nil];
}

- (BOOL) uploadCheckin:(Checkin *)checkin forDelegate:(id<UshahidiDelegate>)delegate {
	@try {
		ASIFormDataRequest *post = [self getAsynchronousPost:[self.deployment getPostCheckin] 
												 forDelegate:delegate 
											   startSelector:@selector(uploadCheckinStarted:) 
											  finishSelector:@selector(uploadCheckinFinished:) 
												failSelector:@selector(uploadCheckinFailed:)];
		[post setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:delegate, @"delegate",
																	 checkin, @"checkin", nil]];
		[post addPostValue:@"checkin" forKey:@"task"];
		[post addPostValue:@"ci" forKey:@"action"];
		[post addPostValue:checkin.latitude forKey:@"lat"];
		[post addPostValue:checkin.longitude forKey:@"lon"];
		[post addPostValue:checkin.message forKey:@"message"];
		[post addPostValue:[Device deviceIdentifier] forKey:@"mobileid"];
		NSInteger filename = 1;
		for(Photo *photo in checkin.photos) {
			if (photo != nil && photo.image != nil && photo.image.size.width > 0 && photo.image.size.height > 0) {
				NSData *jpegData = [photo getJpegData];
				if (jpegData != nil) {
					[post addData:jpegData 
					 withFileName:[NSString stringWithFormat:@"photo%d.jpg", filename++] 
				   andContentType:@"image/jpeg" 
						   forKey:@"photo"];	
				}
			}
		}
		[self.uploadQueue addOperation:post];
		return YES;
	}
	@catch (NSException *e) {
		DLog(@"NSException: %@", e);
		[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
						target:delegate 
					   objects:self, nil, [NSError errorWithDomain:self.deployment.domain 
															  code:HttpStatusInternalServerError 
														  userInfo:[e userInfo]], nil];
	}
	return NO;
}

- (void)uploadCheckinStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	[self dispatchSelector:@selector(uploadingToUshahidi:checkin:) 
					target:[request getDelegate] 
				   objects:self, [request getCheckin], nil];
}

- (void)uploadCheckinFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	if ([request responseStatusCode] != HttpStatusOK) {
		DLog(@"ERROR: %d %@", [request responseStatusCode], [request responseStatusMessage]);
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
						target:[request getDelegate] 
					   objects:self, [request getCheckin], error, nil];
	}
	else {
		DLog(@"RESPONSE: %@", [request responseString]);
		NSDictionary *json = [[request responseString] JSONValue];
		if (json == nil) {
			//DLog(@"RESPONSE: %@", [request responseString]);
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:HttpStatusInternalServerError 
											  message:NSLocalizedString(@"Unable To Checkin", nil)];
			[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
							target:[request getDelegate] 
						   objects:self, [request getCheckin], error, nil];
		}
		else {
			NSDictionary *payload = [json objectForKey:@"payload"];
			DLog(@"PAYLOAD: %@", payload);
			if ([@"true" isEqualToString:[payload objectForKey:@"success"]]) {
				[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
								target:[request getDelegate] 
							   objects:self, [request getCheckin], nil, nil];
			}
			else if ([payload boolForKey:@"success"]) {
				[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
								target:[request getDelegate] 
							   objects:self, [request getCheckin], nil, nil];
			}
			else {
				NSError *error = [NSError errorWithDomain:self.deployment.domain 
													 code:HttpStatusInternalServerError 
												  message:[json objectForKey:@"error"]];
				[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
								target:[request getDelegate] 
							   objects:self, [request getCheckin], error, nil];
			}
		}
	}
}

- (void)uploadCheckinFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
	[self dispatchSelector:@selector(uploadedToUshahidi:checkin:error:) 
					target:[request getDelegate] 
				   objects:self, [request getCheckin], [request error], nil];
}

#pragma mark -
#pragma mark Add/Upload Incidents

- (BOOL)addIncident:(Incident *)incident forDelegate:(id<UshahidiDelegate>)delegate {
	DLog(@"DELEGATE: %@", [delegate class]);
	if (incident != nil) {
		if (incident.identifier == nil) {
			incident.identifier = [NSString getUUID];
		}
		[self.deployment.pending addObject:incident];
		return [self uploadIncident:incident forDelegate:delegate];
	}
	return NO;
}

- (void) uploadIncidentsForDelegate:(id<UshahidiDelegate>)delegate {
	DLog(@"DELEGATE: %@", [delegate class]);
	for(Incident *incident in self.deployment.pending) {
		[self uploadIncident:incident forDelegate:delegate];
	}
}

- (BOOL) uploadIncident:(Incident *)incident forDelegate:(id<UshahidiDelegate>)delegate {
	DLog(@"DELEGATE: %@", [delegate class]);
	@try {
		ASIFormDataRequest *post = [self getAsynchronousPost:[self.deployment getPostReport] 
												 forDelegate:delegate 
											   startSelector:@selector(uploadIncidentStarted:) 
											  finishSelector:@selector(uploadIncidentFinished:) 
												failSelector:@selector(uploadIncidentFailed:)];
		[post setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:delegate, @"delegate",
																	 incident, @"incident", nil]];
		[post addPostValue:@"report" forKey:@"task"];
		[post addPostValue:@"json" forKey:@"resp"];
		[post addPostValue:[incident title] forKey:@"incident_title"];
		[post addPostValue:[incident description] forKey:@"incident_description"];
		[post addPostValue:[incident dateDayMonthYear] forKey:@"incident_date"];
		[post addPostValue:[incident date12Hour] forKey:@"incident_hour"];
		[post addPostValue:[incident dateMinute] forKey:@"incident_minute"];
		[post addPostValue:[incident dateAmPm] forKey:@"incident_ampm"];
		[post addPostValue:[incident categoryIDs] forKey:@"incident_category"];
		[post addPostValue:[incident location] forKey:@"location_name"];
		[post addPostValue:[incident latitude] forKey:@"latitude"];
		[post addPostValue:[incident longitude] forKey:@"longitude"];
		[post addPostValue:[[Settings sharedSettings] firstName] forKey:@"person_first"];
		[post addPostValue:[[Settings sharedSettings] lastName] forKey:@"person_last"];
		[post addPostValue:[[Settings sharedSettings] email] forKey:@"person_email"];
		if (incident.news != nil && [incident.news count] > 0) {
			News *news = [incident.news objectAtIndex:0];
			[post addPostValue:news.url forKey:@"incident_news"];
		}
		if (incident.videos != nil && [incident.videos count] > 0) {
			Video *video = [incident.videos objectAtIndex:0];
			[post addPostValue:video.url forKey:@"incident_video"];
		}
		NSInteger filename = 1;
		for(Photo *photo in incident.photos) {
			if (photo != nil && photo.image != nil && photo.image.size.width > 0 && photo.image.size.height > 0) {
				NSData *jpegData = [photo getJpegData];
				if (jpegData != nil) {
					[post addData:jpegData 
					 withFileName:[NSString stringWithFormat:@"incident_photo%d.jpg", filename++] 
				   andContentType:@"image/jpeg" 
						   forKey:@"incident_photo[]"];	
				}
			}
		}
		[self.uploadQueue addOperation:post];
		return YES;
	}
	@catch (NSException *e) {
		DLog(@"NSException: %@", e);
		[self dispatchSelector:@selector(uploadedToUshahidi:incident:error:) 
						target:delegate 
					   objects:self, incident, [NSError errorWithDomain:self.deployment.domain 
																   code:HttpStatusInternalServerError 
															   userInfo:[e userInfo]], nil];
	}
	return NO;
}

- (void)uploadIncidentStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	Incident *incident = [request getIncident];
	incident.uploading = YES;
	[self dispatchSelector:@selector(uploadingToUshahidi:incident:) 
					target:[request getDelegate]
				   objects:self, incident, nil];
}

- (void)uploadIncidentFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	DLog(@"RESPONSE: %@", [request responseString]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	Incident *incident = [request getIncident];
	incident.uploading = NO;
	if ([request responseStatusCode] != HttpStatusOK) {
		incident.errors = [request responseStatusMessage];
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:@selector(uploadedToUshahidi:incident:error:) 
						target:delegate 
					   objects:self, incident, error, nil];
	}
	else {
		NSDictionary *json = [[request responseString] JSONValue];
		if (json == nil) {
			DLog(@"RESPONSE: %@", [request responseString]);
			incident.errors = NSLocalizedString(@"Unable To Upload Report", nil);
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:HttpStatusInternalServerError 
											  message:NSLocalizedString(@"Unable To Upload Report", nil)];
			[self dispatchSelector:@selector(uploadedToUshahidi:incident:error:) 
							target:delegate 
						   objects:self, incident, error, nil];
		}
		else {
			NSDictionary *payload = [json objectForKey:@"payload"];
			DLog(@"RESPONSE: %@", payload);
			incident.uploading = NO;
			if ([@"true" isEqualToString:[payload objectForKey:@"success"]]) {
				incident.errors = nil;
				DLog(@"Incident Uploaded: %@", incident.title);
				[self.deployment.incidents setObject:incident forKey:incident.identifier];
				[self.deployment.pending removeObject:incident];
				[self dispatchSelector:@selector(downloadedFromUshahidi:incidents:pending:error:hasChanges:) 
								target:delegate 
							   objects:self, [self.deployment.incidents allValues], self.deployment.pending, nil, YES, nil];
			}
			else {
				NSDictionary *messages = [json objectForKey:@"error"];
				if (messages != nil) {
					incident.errors = [messages objectForKey:@"message"];
				}
				else {
					incident.errors = NSLocalizedString(@"Unable To Upload Report", nil);
				}
				NSError *error = [NSError errorWithDomain:self.deployment.domain 
													 code:HttpStatusInternalServerError 
												  message:incident.errors];
				[self dispatchSelector:@selector(uploadedToUshahidi:incident:error:) 
								target:delegate 
							   objects:self, incident, error, nil];
			}
		}	
	}
}

- (void)uploadIncidentFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
	Incident *incident = [request getIncident];
	incident.uploading = NO;
	incident.errors = [[request error] localizedDescription];
	[self dispatchSelector:@selector(uploadedToUshahidi:incident:error:) 
					target:[request getDelegate] 
				   objects:self, incident, [request error], nil];
}

#pragma mark -
#pragma mark Categories

- (BOOL) hasCategories {
	return [self.deployment.categories count] > 0;
}

- (NSArray *) getCategories {
	return [[self.deployment.categories allValues] sortedArrayUsingSelector:@selector(compareByTitle:)];
}

- (NSArray *) getCategoriesForDelegate:(id<UshahidiDelegate>)delegate {
	DLog(@"DELEGATE: %@", [delegate class]);
	[self queueAsynchronousRequest:[self.deployment getCategories] 
					   forDelegate:delegate
					 startSelector:@selector(getCategoriesStarted:)
					finishSelector:@selector(getCategoriesFinished:)
					  failSelector:@selector(getCategoriesFailed:)];
	
	return [[self.deployment.categories allValues] sortedArrayUsingSelector:@selector(compareByTitle:)];
}

- (void) getCategoriesStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [[request url] absoluteString]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	[self dispatchSelector:@selector(downloadingFromUshahidi:categories:) 
					target:delegate 
				   objects:self, [[self.deployment.categories allValues] sortedArrayUsingSelector:@selector(compareByTitle:)], nil];
}

- (void) getCategoriesFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	if ([request responseStatusCode] != HttpStatusOK) {
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:@selector(downloadedFromUshahidi:categories:error:hasChanges:) 
						target:delegate 
					   objects:self, [[self.deployment.categories allValues] sortedArrayUsingSelector:@selector(compareByTitle:)], error, NO, nil];
	}
	else {
		NSDictionary *json = [[request responseString] JSONValue];
		if (json == nil) {
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:HttpStatusInternalServerError 
											  message:NSLocalizedString(@"Invalid Server Response", nil)];
			[self dispatchSelector:@selector(downloadedFromUshahidi:categories:error:hasChanges:) 
							target:delegate 
						   objects:self, [[self.deployment.categories allValues] sortedArrayUsingSelector:@selector(compareByTitle:)], error, NO, nil];
			
		}
		else {
			NSDictionary *payload = [json objectForKey:@"payload"];
			NSArray *categories = [payload objectForKey:@"categories"]; 
			BOOL hasChanges = NO;
			for (NSDictionary *dictionary in categories) {
				Category *category = [[Category alloc] initWithDictionary:[dictionary objectForKey:@"category"]];
				if (category.identifier != nil) {
					Category *existing = [self.deployment.categories objectForKey:category.identifier];
					if (existing == nil) {
						[self.deployment.categories setObject:category forKey:category.identifier];
						hasChanges = YES;
						DLog(@"CATEGORY: %@", dictionary);
					}
					else if ([existing updateWithDictionary:[dictionary objectForKey:@"category"]]) {
						hasChanges = YES;
						DLog(@"CATEGORY: %@", dictionary);
					}
				}
				[category release];
			}
			if (hasChanges) {
				DLog(@"Has New Categories");
			}
			[self dispatchSelector:@selector(downloadedFromUshahidi:categories:error:hasChanges:) 
							target:delegate 
						   objects:self, [[self.deployment.categories allValues] sortedArrayUsingSelector:@selector(compareByTitle:)], nil, hasChanges, nil];
		}		
	}
}

- (void) getCategoriesFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
	[self dispatchSelector:@selector(downloadedFromUshahidi:categories:error:hasChanges:) 
					target:[request getDelegate] 
				   objects:self, nil, [request error], NO, nil];
}

#pragma mark -
#pragma mark Locations

- (BOOL) hasLocations {
	return [self.deployment.locations count] > 0;
}

- (NSArray *) getLocations {
	return [[self.deployment.locations allValues] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (NSArray *) getLocationsForDelegate:(id<UshahidiDelegate>)delegate {
	DLog(@"DELEGATE: %@", [delegate class]);
	[self queueAsynchronousRequest:[self.deployment getLocations] 
					   forDelegate:delegate
					 startSelector:@selector(getLocationsStarted:)
					finishSelector:@selector(getLocationsFinished:)
					  failSelector:@selector(getLocationsFailed:)];
	
	return [[self.deployment.locations allValues] sortedArrayUsingSelector:@selector(compareByName:)];
}

- (void) getLocationsStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [[request url] absoluteString]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	[self dispatchSelector:@selector(downloadingFromUshahidi:locations:) 
					target:delegate 
				   objects:self, [[self.deployment.locations allValues] sortedArrayUsingSelector:@selector(compareByName:)], nil];
}

- (void) getLocationsFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	if ([request responseStatusCode] != HttpStatusOK) {
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:@selector(downloadedFromUshahidi:locations:error:hasChanges:)
						target:delegate
					   objects:self, [[self.deployment.locations allValues] sortedArrayUsingSelector:@selector(compareByName:)], error, NO, nil];
	}
	else {
		NSDictionary *json = [[request responseString] JSONValue];
		if (json == nil) {
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:HttpStatusInternalServerError 
											  message:NSLocalizedString(@"Invalid server response", nil)];
			[self dispatchSelector:@selector(downloadedFromUshahidi:locations:error:hasChanges:)
							target:delegate
						   objects:self, [[self.deployment.locations allValues] sortedArrayUsingSelector:@selector(compareByName:)], error, NO, nil];
		}
		else {
			NSDictionary *payload = [json objectForKey:@"payload"];
			NSArray *locations = [payload objectForKey:@"locations"]; 
			BOOL hasChanges = NO;
			for (NSDictionary *dictionary in locations) {
				Location *location = [[Location alloc] initWithDictionary:[dictionary objectForKey:@"location"]];
				if ([self.deployment containsLocation:location] == NO) {
					[self.deployment.locations setObject:location forKey:location.identifier];
					hasChanges = YES;
					DLog(@"LOCATION: %@", dictionary);
				}
				[location release];
			}
			if (hasChanges) {
				DLog(@"Has New Locations");
			}
			[self dispatchSelector:@selector(downloadedFromUshahidi:locations:error:hasChanges:)
							target:delegate
						   objects:self, [[self.deployment.locations allValues] sortedArrayUsingSelector:@selector(compareByName:)], nil, hasChanges, nil];
		}	
	}
}

- (void) getLocationsFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
	[self dispatchSelector:@selector(downloadedFromUshahidi:locations:error:hasChanges:) 
					target:[request getDelegate] 
				   objects:self, nil, [request error], NO, nil];	
}

#pragma mark -
#pragma mark Incidents

- (Incident *) getIncidentWithIdentifer:(NSString *)identifer {
	Incident *incident = [self.deployment.incidents objectForKey:identifer];
	if (incident != nil) {
		return incident;
	}
	for (Incident *pending in self.deployment.pending) {
		if ([pending.identifier isEqualToString:identifer]) {
			return pending;
		}
	}
	return nil;
}

- (NSArray *) getIncidents {
	return [self.deployment.incidents allValues];
}

- (NSArray *) getIncidentsPending {
	return self.deployment.pending;
}

- (NSArray *) getIncidentsForDelegate:(id<UshahidiDelegate>)delegate {
	DLog(@"DELEGATE: %@", [delegate class]);
	if ([[Settings sharedSettings] downloadMaps]) {
		for (Incident *incident in [self.deployment.incidents allValues]) {
			[self downloadMap:incident forDelegate:delegate];
		}
	}
	if (self.deployment.sinceID != nil) {
		[self queueAsynchronousRequest:[self.deployment getIncidentsBySinceID:self.deployment.sinceID] 
						   forDelegate:delegate
						 startSelector:@selector(getIncidentsStarted:)
						finishSelector:@selector(getIncidentsFinished:)
						  failSelector:@selector(getIncidentsFailed:)];
	}
	else {
		[self queueAsynchronousRequest:[self.deployment getIncidents] 
						   forDelegate:delegate
						 startSelector:@selector(getIncidentsStarted:)
						finishSelector:@selector(getIncidentsFinished:)
						  failSelector:@selector(getIncidentsFailed:)];
	}
	return [self.deployment.incidents allValues];
}

- (void) getIncidentsStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [[request url] absoluteString]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	[self dispatchSelector:@selector(downloadingFromUshahidi:inspections:) 
					target:delegate 
				   objects:self, [self.deployment.incidents allValues], nil];
}

- (void) getIncidentsFinished:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"STATUS: %@", [request responseStatusMessage]);
	id<UshahidiDelegate> delegate = [request getDelegate];
	if ([request responseStatusCode] != HttpStatusOK) {
		NSError *error = [NSError errorWithDomain:self.deployment.domain 
											 code:[request responseStatusCode] 
										  message:[request responseStatusMessage]];
		[self dispatchSelector:@selector(downloadedFromUshahidi:incidents:pending:error:hasChanges:) 
						target:delegate 
					   objects:self, [self.deployment.incidents allValues], self.deployment.pending, error, NO, nil];
	}
	else {
		NSDictionary *json = [[request responseString] JSONValue];
		if (json == nil) {
			DLog(@"RESPONSE: %@", [request responseString]);
			NSError *error = [NSError errorWithDomain:self.deployment.domain 
												 code:HttpStatusInternalServerError 
											  message:NSLocalizedString(@"Invalid Server Response", nil)];
			[self dispatchSelector:@selector(downloadedFromUshahidi:incidents:pending:error:hasChanges:) 
							target:delegate 
						   objects:self, [self.deployment.incidents allValues], self.deployment.pending, error, NO, nil];
		}
		else {
			BOOL hasChanges = NO;
			NSDictionary *payload = [json objectForKey:@"payload"];
			NSArray *incidents = [payload objectForKey:@"incidents"]; 
			for (NSDictionary *dictionary in incidents) {
				Incident *incident = [[Incident alloc] initWithDictionary:[dictionary objectForKey:@"incident"]];
				if (incident.identifier != nil) {
					if ([self isDuplicate:incident]) {
						DLog(@"DUPLICATE: %@", dictionary);
						hasChanges = YES;
					}
					else if ([self.deployment.incidents objectForKey:incident.identifier] == nil) {
						[self.deployment.incidents setObject:incident forKey:incident.identifier];
						DLog(@"INCIDENT: %@", dictionary);
						hasChanges = YES;
					}
					if (self.deployment.sinceID == nil) {
						self.deployment.sinceID = incident.identifier;
					}
					else if ([self.deployment.sinceID intValue] < [incident.identifier intValue]) {
						self.deployment.sinceID = incident.identifier;
					}
				}
				NSDictionary *media = [dictionary objectForKey:@"media"];
				if (media != nil && [media isKindOfClass:[NSArray class]]) {
					for (NSDictionary *item in media) {
						DLog(@"INCIDENT MEDIA: %@", item);
						NSInteger mediatype = [item intForKey:@"type"];
						if (mediatype == MediaTypePhoto) {
							Photo *photo = [[[Photo alloc] initWithDictionary:item] autorelease];
							[incident addPhoto:photo];
							if (photo.url != nil && photo.image == nil && photo.downloading == NO) {
								[self downloadPhoto:incident photo:photo forDelegate:delegate];
							}
						}
						else if (mediatype == MediaTypeVideo) {
							[incident addVideo:[[Video alloc] initWithDictionary:item]];
						}
						else if (mediatype == MediaTypeSound) {
							[incident addSound:[[Sound alloc] initWithDictionary:item]];
						}
						else if (mediatype == MediaTypeNews) {
							[incident addNews:[[News alloc] initWithDictionary:item]];
						}	
					}
				}
				NSDictionary *categories = [dictionary objectForKey:@"categories"];
				if (categories != nil && [categories isKindOfClass:[NSArray class]]) {
					for (NSDictionary *item in categories) {
						DLog(@"INCIDENT CATEGORY: %@", item);
						Category *category = [[Category alloc] initWithDictionary:[item objectForKey:@"category"]];
						if ([incident hasCategory:category] == NO) {
							[incident addCategory:category];
						}
						if (category.identifier != nil && [self.deployment.categories objectForKey:category.identifier] == nil) {
							[self.deployment.categories setObject:category forKey:category.identifier];
						}
						[category release];
					}
				}
				if ([[Settings sharedSettings] downloadMaps] && incident.map == nil) {
					[self downloadMap:incident forDelegate:delegate];
				}
				[incident release];
			}
			if (hasChanges) {
				DLog(@"Has New Incidents");
			}
			self.deployment.synced = [NSDate date];
			[self dispatchSelector:@selector(downloadedFromUshahidi:incidents:pending:error:hasChanges:) 
							target:delegate 
						   objects:self, [self.deployment.incidents allValues], self.deployment.pending, nil, hasChanges, nil];
		}	
	}
}

- (BOOL) isDuplicate:(Incident *)incident {
	for (Incident *existing in [self.deployment.incidents allValues]) {
		if ([existing isDuplicate:incident]) {
			[existing setIdentifier:incident.identifier];
			return YES;
		}
	}
	return NO;
}

- (NSURL *) getUrlForIncident:(Incident *)incident {
	return [NSURL URLWithStrings:self.deployment.url, @"/reports/view/", incident.identifier, nil];
}

- (void) getIncidentsFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
	[self dispatchSelector:@selector(downloadedFromUshahidi:incidents:pending:error:hasChanges:) 
					target:[request getDelegate] 
				   objects:self, nil, nil, [request error], NO, nil];
}

#pragma mark -
#pragma mark Photo

- (void) downloadPhoto:(Incident *)incident photo:(Photo *)photo forDelegate:(id<UshahidiDelegate>)delegate {
	if (photo.url != nil && photo.image == nil && photo.downloading == NO) {
		photo.downloading = YES;
		NSURL *url = nil;
		if ([NSString isNilOrEmpty:photo.imageURL] == NO) {
			url = [NSURL URLWithString:photo.imageURL];
		}
		else if ([[photo.url lowercaseString] hasPrefix:@"http://"] || [[photo.url lowercaseString] hasPrefix:@"https://"]) {
			url = [NSURL URLWithString:photo.url];
		}
		else {
			url = [NSURL URLWithStrings:self.deployment.url, @"/media/uploads/", photo.url, nil];
		}
		DLog(@"downloadPhoto: %@", [url absoluteString]);
		ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
		[request setDelegate:self];
		[request setDidStartSelector:@selector(downloadPhotoStarted:)];
		[request setDidFinishSelector:@selector(downloadPhotoFinished:)];
		[request setDidFailSelector:@selector(downloadPhotoFailed:)];
		[request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:delegate, @"delegate",
																		incident, @"incident",
																		photo, @"photo", nil]];
		[self.photoQueue addOperation:request];
	}
}

- (void) downloadPhotoStarted:(ASIHTTPRequest *)request {
	DLog(@"REQUEST:%@", [request.originalURL absoluteString]);
}

- (void) downloadPhotoFinished:(ASIHTTPRequest *)request {
	id<UshahidiDelegate> delegate = [request getDelegate];
	Incident *incident = (Incident *)[request getIncident];
	Photo *photo = (Photo *)[request getPhoto];
	if (photo != nil) {
		photo.downloading = NO;	
	}
	if ([request error] != nil) {
		DLog(@"ERROR: %@", [[request error] localizedDescription]);
	} 
	else if ([request responseData] != nil) {
		DLog(@"RESPONSE: BINARY IMAGE %@", [request.originalURL absoluteString]);
		photo.image = [UIImage imageWithData:[request responseData]];
		[self dispatchSelector:@selector(downloadedFromUshahidi:incident:photo:) 
						target:delegate 
					   objects:self, incident, photo, nil];
	}
	else {
		DLog(@"RESPONSE: %@", [request responseString]);
	}
}

- (void) downloadPhotoFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST:%@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
	Photo *photo = (Photo *)[request getPhoto];
	if (photo != nil) {
		photo.downloading = NO;
	}
}

#pragma mark -
#pragma mark Maps

- (void) downloadMap:(Incident *)incident forDelegate:(id<UshahidiDelegate>)delegate {
	if (incident.map == nil && incident.latitude != nil && incident.longitude != nil) {
		CGRect screen = [[UIScreen mainScreen] bounds];
		NSMutableString *url = [NSMutableString stringWithString:kGoogleStaticMaps];
		[url appendFormat:@"?center=%@,%@", incident.latitude, incident.longitude];
		[url appendFormat:@"&markers=%@,%@", incident.latitude, incident.longitude];
		[url appendFormat:@"&size=%dx%d", (int)CGRectGetWidth(screen), (int)CGRectGetWidth(screen)];
		[url appendFormat:@"&zoom=%d", [[Settings sharedSettings] mapZoomLevel]];
		[url appendFormat:@"&sensor=false"];
		DLog(@"REQUEST: %@", url);
		
		ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
		[request setDelegate:self];
		[request setDidFinishSelector:@selector(downloadMapFinished:)];
		[request setDidFailSelector:@selector(downloadMapFailed:)];
		[request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:delegate, @"delegate",
																		incident, @"incident", nil]];
		[self.mapQueue addOperation:request];	
	}
}

- (void) downloadMapFinished:(ASIHTTPRequest *)request {
	id<UshahidiDelegate> delegate = [request getDelegate];
	Incident *incident = (Incident *)[request getIncident];
	if ([request error] != nil) {
		DLog(@"ERROR: %@", [[request error] localizedDescription]);
	} 
	else if ([request responseData] != nil) {
		DLog(@"RESPONSE: MAP IMAGE %@", [request.originalURL absoluteString]);
		UIImage *map = [UIImage imageWithData:[request responseData]];
		if (map.size.width == kGoogleOverCapacitySize && map.size.height == kGoogleOverCapacitySize) {
			DLog(@"OVER CAPACITY, CANCELLING MAP QUEUE");
			[self.mapQueue cancelAllOperations];	
		}
		else {
			incident.map = map;
			[self dispatchSelector:@selector(downloadedFromUshahidi:incident:map:) 
							target:delegate 
						   objects:self, incident, incident.map, nil];
		}
	}
	else {
		DLog(@"RESPONSE: %@", [request responseString]);
	}
}

- (void) downloadMapFailed:(ASIHTTPRequest *)request {
	DLog(@"REQUEST: %@", [request.originalURL absoluteString]);
	DLog(@"ERROR: %@", [[request error] localizedDescription]);
}

#pragma mark -
#pragma mark ASIHTTPRequest

- (ASIHTTPRequest *) queueAsynchronousRequest:(NSString *)url 
								  forDelegate:(id<UshahidiDelegate>)delegate
								startSelector:(SEL)startSelector
							   finishSelector:(SEL)finishSelector
								 failSelector:(SEL)failSelector {
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
	[request setDelegate:self];
	[request setShouldRedirect:YES];
	[request setDidStartSelector:startSelector];
	[request setDidFinishSelector:finishSelector];
	[request setDidFailSelector:failSelector];
	[request setUserInfo:[NSDictionary dictionaryWithObject:delegate forKey:@"delegate"]];
	
	[self.mainQueue addOperation:request];
	
	return request;
}

- (ASIFormDataRequest *) getAsynchronousPost:(NSString *)url 
								 forDelegate:(id<UshahidiDelegate>)delegate
							   startSelector:(SEL)startSelector
							  finishSelector:(SEL)finishSelector
								failSelector:(SEL)failSelector {
	ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:url]];
	[request setDelegate:self];
	[request setTimeOutSeconds:180];
	[request setShouldRedirect:YES];
	[request setAllowCompressedResponse:NO];
	[request setShouldCompressRequestBody:NO];
	[request setValidatesSecureCertificate:NO];
	[request addRequestHeader:@"Accept" value:@"*/*"];
	[request addRequestHeader:@"Cache-Control" value:@"no-cache"];
	[request addRequestHeader:@"Connection" value:@"Keep-Alive"];
	[request setDidStartSelector:startSelector];
	[request setDidFinishSelector:finishSelector];
	[request setDidFailSelector:failSelector];
	[request setUserInfo:[NSDictionary dictionaryWithObject:delegate forKey:@"delegate"]];
	
	return request;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.mainQueue && [keyPath isEqual:@"operations"]) {
        if ([self.mainQueue.operations count] == 0) {
            DLog(@"MainQueue Finished");
			[[NSNotificationCenter defaultCenter] postNotificationName:kMainQueueFinished object:nil];
		}
    }
	else if (object == self.mapQueue && [keyPath isEqual:@"operations"]) {
        if ([self.mapQueue.operations count] == 0) {
			DLog(@"MapQueue Finished");
			[[NSNotificationCenter defaultCenter] postNotificationName:kMapQueueFinished object:nil];
		}
    }
	else if (object == self.photoQueue && [keyPath isEqual:@"operations"]) {
        if ([self.photoQueue.operations count] == 0) {
			DLog(@"PhotoQueue Finished");
			[[NSNotificationCenter defaultCenter] postNotificationName:kPhotoQueueFinished object:nil];
		}
    }
	else if (object == self.uploadQueue && [keyPath isEqual:@"operations"]) {
        if ([self.uploadQueue.operations count] == 0) {
			DLog(@"UploadQueue Finished");
			[[NSNotificationCenter defaultCenter] postNotificationName:kUploadQueueFinished object:nil];
		}
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
