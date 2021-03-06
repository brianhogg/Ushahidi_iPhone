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

#import "IncidentsViewController.h"
#import "AddIncidentViewController.h"
#import "ViewIncidentViewController.h"
#import "checkinViewController.h"
#import "MapViewController.h"
#import "IncidentTableCell.h"
#import "TableCellFactory.h"
#import "UIColor+Extension.h"
#import "LoadingViewController.h"
#import "NSDate+Extension.h"
#import "AlertView.h"
#import "InputView.h"
#import "Incident.h"
#import "Deployment.h"
#import "Category.h"
#import "MKMapView+Extension.h"
#import "MKPinAnnotationView+Extension.h"
#import "NSString+Extension.h"
#import "MapAnnotation.h"
#import "Settings.h"
#import "TableHeaderView.h"
#import "IncidentTableView.h"
#import "IncidentMapView.h"
#import "CheckinMapView.h"
#import "Internet.h"
#import "Checkin.h"
#import "User.h"
#import "ItemPicker.h"

@interface IncidentsViewController ()

@property(nonatomic,retain) NSMutableArray *pending;
@property(nonatomic,retain) ItemPicker *itemPicker;
@property(nonatomic,retain) NSMutableArray *categories;
@property(nonatomic,retain) Category *category;
@property(nonatomic,retain) NSMutableArray *checkins;
@property(nonatomic,retain) NSMutableArray *users;
@property(nonatomic,retain) User *user;

- (void) updateSyncedLabel;
- (void) pushViewIncidentsViewController;
- (void) populateReportPins:(BOOL)resizeMap;
- (void) populateCheckinPins:(BOOL)resizeMap;

- (void) mainQueueFinished;
- (void) mapQueueFinished;
- (void) photoQueueFinished;
- (void) uploadQueueFinished;

@end

@implementation IncidentsViewController

@synthesize addIncidentViewController, viewIncidentViewController, checkinViewController;
@synthesize deployment, tableSort, mapType, viewMode, pending;
@synthesize itemPicker, categories, category, users, user, checkins;
@synthesize incidentTableView, incidentMapView, checkinMapView;

typedef enum {
	ViewModeTable,
	ViewModeMap,
	ViewModeCheckin
} ViewMode;

typedef enum {
	TableSectionPending,
	TableSectionIncidents
} TableSection;

typedef enum {
	TableSortDate,
	TableSortTitle,
	TableSortVerified
} TableSort;

typedef enum {
	ItemPickerCategories,
	ItemPickerUsers
} ItemPickerEnum;

#pragma mark -
#pragma mark Handlers

- (IBAction) addReport:(id)sender {
	DLog(@"");
	[self presentModalViewController:self.addIncidentViewController animated:YES];
}

- (IBAction) addCheckin:(id)sender {
	DLog(@"");
	[self presentModalViewController:self.checkinViewController animated:YES];
}

- (IBAction) refreshReports:(id)sender {
	DLog(@"");
	self.incidentTableView.refreshButton.enabled = NO;
	self.incidentMapView.refreshButton.enabled = NO;
	[self.loadingView showWithMessage:NSLocalizedString(@"Loading...", nil)];
	[[Ushahidi sharedUshahidi] getIncidentsForDelegate:self];
	[[Ushahidi sharedUshahidi] uploadIncidentsForDelegate:self];
}

- (IBAction) refreshCheckins:(id)sender {
	self.checkinMapView.refreshButton.enabled = NO;
	[self.loadingView showWithMessage:NSLocalizedString(@"Loading...", nil)];
	[[Ushahidi sharedUshahidi] getCheckinsForDelegate:self];
}

- (IBAction) tableSortChanged:(id)sender {
	UISegmentedControl *segmentControl = (UISegmentedControl *)sender;
	if (segmentControl.selectedSegmentIndex == TableSortDate) {
		DLog(@"TableSortDate");
	}
	else if (segmentControl.selectedSegmentIndex == TableSortTitle) {
		DLog(@"TableSortTitle");
	}
	else if (segmentControl.selectedSegmentIndex == TableSortVerified) {
		DLog(@"TableSortVerified");
	}
	[self filterRows:YES];
}

- (IBAction) reportsMapTypeChanged:(id)sender {
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
	DLog(@"reportsMapTypeChanged: %d", segmentedControl.selectedSegmentIndex);
	self.incidentMapView.mapView.mapType = segmentedControl.selectedSegmentIndex;
}

- (IBAction) checkinsMapTypeChanged:(id)sender {
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
	DLog(@"checkinsMapTypeChanged: %d", segmentedControl.selectedSegmentIndex);
	self.checkinMapView.mapView.mapType = segmentedControl.selectedSegmentIndex;
}

- (IBAction) viewModeChanged:(id)sender {
	DLog(@"");
	UISegmentedControl *segmentControl = (UISegmentedControl *)sender;
	if (segmentControl.selectedSegmentIndex == ViewModeTable) {
		DLog(@"ViewModeTable");
		self.incidentTableView.frame = self.view.frame;
		[UIView beginAnimations:@"ViewModeTable" context:nil];
		[UIView setAnimationDuration:0.6];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.view cache:YES];
		[self.incidentMapView removeFromSuperview];
		[self.checkinMapView removeFromSuperview];
		[self.view addSubview:self.incidentTableView];
		[UIView commitAnimations];
		self.incidentTableView.filterButton.enabled = [self.categories count] > 0;
		[self.tableView reloadData];
	}
	else if (segmentControl.selectedSegmentIndex == ViewModeMap) {
		DLog(@"ViewModeMap");
		self.incidentMapView.frame = self.view.frame;
		[UIView beginAnimations:@"ViewModeMap" context:nil];
		[UIView setAnimationDuration:0.6];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.view cache:YES];
		[self.incidentTableView removeFromSuperview];
		[self.checkinMapView removeFromSuperview];
		[self.view addSubview:self.incidentMapView];
		[UIView commitAnimations];
		if ([self.incidentMapView.mapView.annotations count] == 0) {
			[self populateReportPins:YES];
		}
		self.incidentMapView.filterButton.enabled = [self.categories count] > 0;
	}
	else if (segmentControl.selectedSegmentIndex == ViewModeCheckin) {
		DLog(@"ViewModeCheckin");
		self.checkinMapView.frame = self.view.frame;
		[UIView beginAnimations:@"ViewModeCheckin" context:nil];
		[UIView setAnimationDuration:0.6];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.view cache:YES];
		[self.incidentTableView removeFromSuperview];
		[self.incidentMapView removeFromSuperview];
		[self.view addSubview:self.checkinMapView];
		[UIView commitAnimations];
		[self populateCheckinPins:YES];
	}
}

- (IBAction) reportsFilterChanged:(id)sender event:(UIEvent*)event {
	DLog(@"");
	NSMutableArray *items = [NSMutableArray arrayWithObject:NSLocalizedString(@" --- ALL CATEGORIES --- ", nil)];
	for (Category *theCategory in self.categories) {
		if ([NSString isNilOrEmpty:[theCategory title]] == NO) {
		[items addObject:theCategory.title];
		}
	}
	if (event != nil) {
		UIView *toolbar = [[event.allTouches anyObject] view];
		CGRect rect = CGRectMake(toolbar.frame.origin.x, self.view.frame.size.height - toolbar.frame.size.height, toolbar.frame.size.width, toolbar.frame.size.height);
		[self.itemPicker showWithItems:items 
						  withSelected:[self.category title] 
							   forRect:rect 
								   tag:ItemPickerCategories];
	}
	else {
		[self.itemPicker showWithItems:items 
						  withSelected:[self.category title] 
							   forRect:CGRectMake(100, self.view.frame.size.height, 0, 0) 
								   tag:ItemPickerCategories];	
	}
}

- (IBAction) checkinsFilterChanged:(id)sender event:(UIEvent*)event {
	DLog(@"");
	NSMutableArray *items = [NSMutableArray arrayWithObject:NSLocalizedString(@" --- ALL USERS --- ", nil)];
	for (User *theUser in self.users) {
		if ([NSString isNilOrEmpty:[theUser name]] == NO) {
			[items addObject:[theUser name]];
		}
	}
	if (event != nil) {
		UIView *toolbar = [[event.allTouches anyObject] view];
		CGRect rect = CGRectMake(toolbar.frame.origin.x, self.view.frame.size.height - toolbar.frame.size.height, toolbar.frame.size.width, toolbar.frame.size.height);
		[self.itemPicker showWithItems:items 
						  withSelected:[self.user name] 
							   forRect:rect 
								   tag:ItemPickerUsers];
	}
	else {
		[self.itemPicker showWithItems:items 
						  withSelected:[self.user name] 
							   forRect:CGRectMake(100, self.view.frame.size.height, 0, 0) 
								   tag:ItemPickerUsers];	
	}
}

- (void) updateSyncedLabel {
	if (self.deployment.synced) {
		[self setTableFooter:[NSString stringWithFormat:@"%@ %@", 
							  NSLocalizedString(@"Last Sync", nil), 
							  [self.deployment.synced dateToString:@"h:mm a, MMMM d, yyyy"]]];	
	}
	else {
		[self setTableFooter:nil];
	}
}

- (void) populateReportPins:(BOOL)resizeMap {
	self.incidentMapView.mapView.showsUserLocation = NO;
	[self.incidentMapView.mapView removeAllPins];
	self.incidentMapView.mapView.showsUserLocation = YES;
	for (Incident *incident in self.filteredRows) {
		[self.incidentMapView.mapView addPinWithTitle:incident.title 
							 subtitle:incident.dateString 
							 latitude:incident.latitude 
							longitude:incident.longitude
							   object:incident
							 pinColor:MKPinAnnotationColorRed];
	}
	for (Incident *incident in self.pending) {
		[self.incidentMapView.mapView addPinWithTitle:incident.title 
							 subtitle:incident.dateString 
							 latitude:incident.latitude 
							longitude:incident.longitude 
							   object:incident
							 pinColor:MKPinAnnotationColorPurple];
	}
	if (resizeMap) {
		[self.incidentMapView.mapView resizeRegionToFitAllPins:NO animated:YES];
	}
}

- (void) populateCheckinPins:(BOOL)resizeMap {
	[self.checkins removeAllObjects];
	[self.checkinMapView.mapView removeAllPins];
	[self.checkins addObjectsFromArray:[[Ushahidi sharedUshahidi] getCheckinsForDelegate:self]];
	for (Checkin *checkin in self.checkins) {
		[self.checkinMapView.mapView addPinWithTitle:checkin.message 
											subtitle:checkin.dateString 
											latitude:checkin.latitude 
										   longitude:checkin.longitude 
											  object:checkin
											pinColor:MKPinAnnotationColorRed];
	}
	[self.checkinMapView.mapView resizeRegionToFitAllPins:NO animated:YES];	
}

#pragma mark -
#pragma mark UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	self.pending = [[NSMutableArray alloc] initWithCapacity:0];
	self.checkins = [[NSMutableArray alloc] initWithCapacity:0];
	self.itemPicker = [[ItemPicker alloc] initWithDelegate:self forController:self];
	self.tableView.backgroundColor = [UIColor ushahidiLiteTan];
	self.oddRowColor = [UIColor ushahidiLiteTan];
	self.evenRowColor = [UIColor ushahidiDarkTan];
	[self showSearchBarWithPlaceholder:NSLocalizedString(@"Search reports...", nil)];
	[self setHeader:NSLocalizedString(@"Pending Upload", nil) atSection:TableSectionPending];
	[self setHeader:NSLocalizedString(@"All Categories", nil) atSection:TableSectionIncidents];
}

- (void)viewDidUnload {
    [super viewDidUnload];
	self.addIncidentViewController = nil;
	self.viewIncidentViewController = nil;
	self.checkins = nil;
	self.tableSort = nil;
	self.mapType = nil;
	self.viewMode = nil;
	self.incidentTableView = nil;
	self.incidentMapView = nil;
	self.checkinMapView = nil;
	self.pending = nil;
	self.itemPicker = nil;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	DLog(@"willBePushed: %d", self.willBePushed);
	if (self.incidentTableView.superview == nil && 
		self.incidentMapView.superview == nil && 
		self.checkinMapView.superview == nil) {
		self.incidentTableView.frame = self.view.frame;
		self.incidentMapView.frame = self.view.frame;
		[self.view addSubview:self.incidentTableView];
	}
	if (self.deployment != nil) {
		self.title = self.deployment.name;
	}
	[self.allRows removeAllObjects];
	if (self.willBePushed) {
		[self.allRows addObjectsFromArray:[[Ushahidi sharedUshahidi] getIncidentsForDelegate:self]];
		self.category = nil;
		if ([[Ushahidi sharedUshahidi] hasCategories]) {
			self.categories = [NSMutableArray arrayWithArray:[[Ushahidi sharedUshahidi] getCategories]];
		}
		else {
			self.categories = [NSMutableArray arrayWithArray:[[Ushahidi sharedUshahidi] getCategoriesForDelegate:self]];
		}
		if ([[Ushahidi sharedUshahidi] hasUsers]) {
			self.users = [NSMutableArray arrayWithArray:[[Ushahidi sharedUshahidi] getUsers]];
		}
		else {
			self.users = [NSMutableArray arrayWithCapacity:0];
		}
		if ([[Ushahidi sharedUshahidi] hasLocations]) {
			//DO NOTHING
		}
		else {
			[[Ushahidi sharedUshahidi] getLocationsForDelegate:self];
		}
		if ([self.categories count] == 0) {
			[self.loadingView showWithMessage:NSLocalizedString(@"Loading...", nil)];	
		}
		[self setHeader:NSLocalizedString(@"All Categories", nil) atSection:TableSectionIncidents];
		[self.incidentMapView setLabel:NSLocalizedString(@"All Categories", nil)];
	}
	else {
		[self.allRows addObjectsFromArray:[[Ushahidi sharedUshahidi] getIncidents]];
	}
	[self.pending removeAllObjects];
	[self.pending addObjectsFromArray:[[Ushahidi sharedUshahidi] getIncidentsPending]];
	[self filterRows:YES];
	if (self.willBePushed) {
		if (self.incidentTableView.superview != nil) {
			[self updateSyncedLabel];
			[self.tableView reloadData];
			self.incidentTableView.filterButton.enabled = [self.categories count] > 0;
			self.incidentMapView.filterButton.enabled = [self.categories count] > 0;
		}
		else if (self.incidentMapView.superview != nil) {
			[self populateReportPins:YES];
		}
		else if (self.checkinMapView.superview != nil) {
			[self populateCheckinPins:YES];
		}
	}
	if (animated) {
		[[Settings sharedSettings] setLastIncident:nil];
	}
	if ([[Ushahidi sharedUshahidi] deploymentSupportsCheckins]) {
		if ([self.viewMode numberOfSegments] != ViewModeCheckin + 1) {
			[self.viewMode insertSegmentWithImage:[UIImage imageNamed:@"checkin.png"] atIndex:ViewModeCheckin animated:NO];
			CGRect rect = self.viewMode.frame;
			rect.size.width = 115;
			self.viewMode.frame = rect;
		}
	}
	else {
		[self.viewMode removeSegmentAtIndex:ViewModeCheckin animated:NO];
		CGRect rect = self.viewMode.frame;
		rect.size.width = 80;
		self.viewMode.frame = rect;
	}
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainQueueFinished) name:kMainQueueFinished object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapQueueFinished) name:kMapQueueFinished object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(photoQueueFinished) name:kPhotoQueueFinished object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadQueueFinished) name:kUploadQueueFinished object:nil];
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self.alertView showInfoOnceOnly:NSLocalizedString(@"Click the Map button to view the report map, the Filter button to filter by category or the Compose button to create a new incident report.", nil)];
}

- (void) viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kMainQueueFinished object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kMapQueueFinished object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kPhotoQueueFinished object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kUploadQueueFinished object:nil];
}

- (void)dealloc {
	[addIncidentViewController release];
	[viewIncidentViewController release];
	[checkinViewController release];
	[deployment release];
	[tableSort release];
	[mapType release];
	[viewMode release];
	[pending release];
	[itemPicker release];
	[categories release];
	[category release];
	[incidentTableView release];
	[incidentMapView release];
	[checkinMapView release];
	[checkins release];
	[users release];
	[user release];
    [super dealloc];
}

#pragma mark -
#pragma mark UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)theTableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)theTableView numberOfRowsInSection:(NSInteger)section {
	if (section == TableSectionPending) {
		return [self.pending count];
	}
	if (section == TableSectionIncidents) {
		return [self.filteredRows count];
	}
	return 0;
}

- (CGFloat)tableView:(UITableView *)theTableView heightForHeaderInSection:(NSInteger)section {
	if (section == TableSectionPending && [self.pending count] > 0) {
		return [TableHeaderView getViewHeight];
	}
	else if (section == TableSectionIncidents) {
		return [TableHeaderView getViewHeight];
	}
	return 0;
}

- (CGFloat)tableView:(UITableView *)theTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [IncidentTableCell getCellHeight];
}

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	IncidentTableCell *cell = [TableCellFactory getIncidentTableCellForTable:theTableView indexPath:indexPath];
	Incident *incident = indexPath.section == TableSectionIncidents
		? [self filteredRowAtIndexPath:indexPath] : [self.pending objectAtIndex:indexPath.row];
	if (incident != nil) {
		[cell setTitle:incident.title];
		[cell setLocation:incident.location];
		[cell setCategory:incident.categoryNames];
		[cell setDate:incident.dateString];
		[cell setVerified:incident.verified];
		UIImage *image = [incident getFirstPhotoThumbnail];
		if (image != nil) {
			[cell setImage:image];
		}
		else if (incident.map != nil) {
			[cell setImage:incident.map];
		}
		else {
			[cell setImage:nil];
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleGray;
		[cell setUploading:indexPath.section == TableSectionPending && incident.uploading];
	}
	else {
		[cell setTitle:nil];
		[cell setLocation:nil];
		[cell setCategory:nil];
		[cell setDate:nil];
		[cell setImage:nil];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	return cell;
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[theTableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == TableSectionIncidents) {
		self.viewIncidentViewController.pending = NO;
		self.viewIncidentViewController.incident = [self filteredRowAtIndexPath:indexPath];
		self.viewIncidentViewController.incidents = self.filteredRows;
	}
	else {
		self.viewIncidentViewController.pending = YES;
		self.viewIncidentViewController.incident = [self.pending objectAtIndex:indexPath.row];
		self.viewIncidentViewController.incidents = self.pending;
	}
	if (self.editing) {
		[self.view endEditing:YES];
		[self performSelector:@selector(pushViewIncidentsViewController) withObject:nil afterDelay:0.1];
	}
	else {
		[self pushViewIncidentsViewController];
	}
}

- (void) pushViewIncidentsViewController {
	[self.navigationController pushViewController:self.viewIncidentViewController animated:YES];
}

#pragma mark -
#pragma mark UISearchBarDelegate

- (void) filterRows:(BOOL)reload {
	[self.filteredRows removeAllObjects];
	NSString *searchText = [self getSearchText];
	NSArray *incidents;
	if (self.tableSort.selectedSegmentIndex == TableSortDate) {
		incidents = [self.allRows sortedArrayUsingSelector:@selector(compareByDate:)];
	}
	else if (self.tableSort.selectedSegmentIndex == TableSortVerified) {
		incidents = [self.allRows sortedArrayUsingSelector:@selector(compareByVerified:)];
	}
	else {
		incidents = [self.allRows sortedArrayUsingSelector:@selector(compareByTitle:)];
	}
	for (Incident *incident in incidents) {
		if (self.category != nil) {
			if ([incident hasCategory:self.category] && [incident matchesString:searchText]) {
				[self.filteredRows addObject:incident];
			}
		}
		else if ([incident matchesString:searchText]) {
			[self.filteredRows addObject:incident];
		}
	}
	if (self.incidentTableView.superview != nil) {
		if (reload) {
			[self.tableView reloadData];	
			[self.tableView flashScrollIndicators];	
		}
	}
	else if (self.incidentMapView.superview != nil) {
		[self populateReportPins:reload];
	}
} 

#pragma mark -
#pragma mark UshahidiDelegate

- (void) downloadingFromUshahidi:(Ushahidi *)ushahidi categories:(NSArray *)theCategories {
	DLog(@"Downloading Categories...");
	[self.loadingView showWithMessage:NSLocalizedString(@"Categories...", nil)];
}

- (void) downloadingFromUshahidi:(Ushahidi *)ushahidi locations:(NSArray *)locations {
	DLog(@"Downloading Locations...");
	[self.loadingView showWithMessage:NSLocalizedString(@"Locations...", nil)];
}

- (void) downloadingFromUshahidi:(Ushahidi *)ushahidi incidents:(NSArray *)incidents pending:(NSArray *)thePending {
	DLog(@"Downloading Incidents...");
	[self.loadingView showWithMessage:NSLocalizedString(@"Incidents...", nil)];
}

- (void) downloadedFromUshahidi:(Ushahidi *)ushahidi incidents:(NSArray *)incidents pending:(NSArray *)thePending error:(NSError *)error hasChanges:(BOOL)hasChanges {
	if (error != nil) {
		DLog(@"error: %d %@", [error code], [error localizedDescription]);
		if ([error code] == UnableToCreateRequest) {
			[self.loadingView hide];
			[self.alertView showOkWithTitle:NSLocalizedString(@"Request Error", nil) 
								 andMessage:[error localizedDescription]];
		}
		else if ([error code] == NoInternetConnection) {
			if ([self.loadingView isShowing]) {
				[self.loadingView hide];
				[self.alertView showOkWithTitle:NSLocalizedString(@"No Internet", nil) 
									 andMessage:[error localizedDescription]];
			}
		}
		else if ([self.loadingView isShowing]){
			[self.loadingView hide];
			[self.alertView showOkWithTitle:NSLocalizedString(@"Server Error", nil) 
								 andMessage:[error localizedDescription]];
		}
	}
	else if (hasChanges) {
		DLog(@"incidents: %d", [incidents count]);
		[self updateSyncedLabel];
		[self.allRows removeAllObjects];
		if (self.tableSort.selectedSegmentIndex == TableSortDate) {
			[self.allRows addObjectsFromArray:[incidents sortedArrayUsingSelector:@selector(compareByDate:)]];
		}
		else if (self.tableSort.selectedSegmentIndex == TableSortVerified) {
			[self.allRows addObjectsFromArray:[incidents sortedArrayUsingSelector:@selector(compareByVerified:)]];
		}
		else {
			[self.allRows addObjectsFromArray:[incidents sortedArrayUsingSelector:@selector(compareByTitle:)]];
		}
		[self.filteredRows removeAllObjects];
		[self.filteredRows addObjectsFromArray:self.allRows];
		[self.pending removeAllObjects];
		[self.pending addObjectsFromArray:thePending];
		if (self.incidentTableView.superview != nil) {
			[self.tableView reloadData];
			[self.tableView flashScrollIndicators];	
		}
		else if (self.incidentMapView.superview != nil) {
			[self populateReportPins:YES];
		}
		DLog(@"Re-Adding Incidents");
	}
	else {
		DLog(@"No Changes Incidents");
		[self updateSyncedLabel];
		[self.tableView reloadData];
	}
	self.incidentTableView.refreshButton.enabled = YES;
	self.incidentMapView.refreshButton.enabled = YES;
}

- (void) uploadingToUshahidi:(Ushahidi *)ushahidi incident:(Incident *)incident {
	if (incident != nil){
		NSInteger row = [self.pending indexOfObject:incident];
		DLog(@"Incident: %d %@", row, incident.title);
		if (row > -1) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:TableSectionPending];
			IncidentTableCell *cell = (IncidentTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
			if (cell != nil) {
				[cell setUploading:YES];
			}
		}
		else {
			[self.tableView reloadData];
		}
	}
	else {
		DLog(@"Incident is NULL");
		[self.tableView reloadData];
	}
}

- (void) uploadedToUshahidi:(Ushahidi *)ushahidi incident:(Incident *)incident error:(NSError *)error {
	if (error != nil) {
		DLog(@"error: %d %@", [error code], [error localizedDescription]);
		if ([error code] > NoInternetConnection) {
			[self.loadingView hide];
			[self.alertView showOkWithTitle:NSLocalizedString(@"Upload Error", nil) 
								 andMessage:[error localizedDescription]];
		}
	}
	if (incident != nil) {
		NSInteger row = [self.pending indexOfObject:incident];
		DLog(@"Incident: %d %@", row, incident.title);
		if (row > -1) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:TableSectionPending];
			IncidentTableCell *cell = (IncidentTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
			if (cell != nil) {
				[cell setUploading:NO];
			}
		}
		[self.loadingView showWithMessage:NSLocalizedString(@"Uploaded", nil)];
		[self.loadingView hideAfterDelay:1.0];
	}
	else {
		DLog(@"Incident is NULL");
	}
}

- (void) downloadedFromUshahidi:(Ushahidi *)ushahidi incident:(Incident *)incident map:(UIImage *)map {
	DLog(@"downloadedFromUshahidi:incident:map:");
	NSInteger row = [self.filteredRows indexOfObject:incident];
	if (row != NSNotFound) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:TableSectionIncidents];
		IncidentTableCell *cell = (IncidentTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
		if (cell != nil && [incident getFirstPhotoThumbnail] == nil) {
			[cell setImage:map];
		}
	}
	else {
		[self.tableView reloadData];
	}
}

- (void) downloadedFromUshahidi:(Ushahidi *)ushahidi incident:(Incident *)incident photo:(Photo *)photo {
	DLog(@"downloadedFromUshahidi:incident:photo:%@ indexPath:%@", [photo url], [photo indexPath]);
	if (photo != nil && photo.indexPath != nil) {
		IncidentTableCell *cell = (IncidentTableCell *)[self.tableView cellForRowAtIndexPath:photo.indexPath];
		if (cell != nil) {
			if (photo.thumbnail != nil) {
				[cell setImage:photo.thumbnail];
			}
			else {
				[cell setImage:photo.image];
			}
		}	
	}
	else {
		[self.tableView reloadData];
	}
}

- (void) downloadedFromUshahidi:(Ushahidi *)ushahidi categories:(NSArray *)theCategories error:(NSError *)error hasChanges:(BOOL)hasChanges {
	if (error != nil) {
		DLog(@"error: %d %@", [error code], [error localizedDescription]);
	}
	else if(hasChanges) {
		[self.categories removeAllObjects];
		for (Category *theCategory in theCategories) {
			[self.categories addObject:theCategory];
		}
		DLog(@"Re-Adding Categories");
	}
	else {
		DLog(@"No Changes Categories");
	}
	self.incidentTableView.filterButton.enabled = [self.categories count] > 0;
	self.incidentMapView.filterButton.enabled = [self.categories count] > 0;
}

- (void) downloadingFromUshahidi:(Ushahidi *)ushahidi checkins:(NSArray *)checkins {
	[self.loadingView showWithMessage:NSLocalizedString(@"Checkins...", nil)];
}

- (void) downloadedFromUshahidi:(Ushahidi *)ushahidi checkins:(NSArray *)theCheckins error:(NSError *)error hasChanges:(BOOL)hasChanges {
	if (error != nil) {
		DLog(@"error: %d %@", [error code], [error localizedDescription]);
	}
	else if (hasChanges) {
		DLog(@"Re-Adding Checkins: %d", [checkins count]);
		[self.checkins removeAllObjects];
		[self.checkins addObjectsFromArray:theCheckins];
		[self.checkinMapView.mapView removeAllPins];
		for (Checkin *checkin in self.checkins) {
			[self.checkinMapView.mapView addPinWithTitle:checkin.message 
												subtitle:checkin.dateString 
												latitude:checkin.latitude 
											   longitude:checkin.longitude 
												  object:checkin
												pinColor:MKPinAnnotationColorRed];
		}
		[self.checkinMapView.mapView resizeRegionToFitAllPins:NO animated:YES];
	}
	else {
		DLog(@"No Changes Checkins");
	}
	[self.loadingView hide];
	self.checkinMapView.refreshButton.enabled = YES;
}

- (void) downloadedFromUshahidi:(Ushahidi *)ushahidi users:(NSArray *)theUsers hasChanges:(BOOL)hasChanges {
	if (hasChanges) {
		DLog(@"Re-Adding Users: %d", [theUsers count]);
		[self.users removeAllObjects];
		[self.users addObjectsFromArray:theUsers];
	}
	else {
		DLog(@"No Changes Users");
	}
	self.checkinMapView.filterButton.enabled = YES;
}

- (void) mainQueueFinished {
	DLog(@"");
	[self.loadingView hideAfterDelay:1.0];
}

- (void) mapQueueFinished {
	DLog(@"");
}

- (void) photoQueueFinished {
	DLog(@"");
}

- (void) uploadQueueFinished {
	DLog(@"");
}

#pragma mark -
#pragma mark MKMapView

- (MKAnnotationView *) mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation {
	MKPinAnnotationView *annotationView = [MKPinAnnotationView getPinForMap:theMapView andAnnotation:annotation];
	if ([annotation class] != MKUserLocation.class) {
		UIButton *annotationButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
		[annotationButton addTarget:self action:@selector(annotationClicked:) forControlEvents:UIControlEventTouchUpInside];
		annotationView.rightCalloutAccessoryView = annotationButton;
	}
	return annotationView;
}

- (void) annotationClicked:(UIButton *)button {
	MKPinAnnotationView *annotationView = (MKPinAnnotationView *)[[button superview] superview];
	MapAnnotation *mapAnnotation = (MapAnnotation *)annotationView.annotation;
	if ([mapAnnotation class] == MKUserLocation.class) {
		[self.alertView showOkWithTitle:NSLocalizedString(@"User Location", nil) andMessage:[NSString stringWithFormat:@"%f,%f", mapAnnotation.coordinate.latitude, mapAnnotation.coordinate.longitude]];
	}
	else {
		DLog(@"title:%@ latitude:%f longitude:%f", mapAnnotation.title, mapAnnotation.coordinate.latitude, mapAnnotation.coordinate.longitude);
		self.viewIncidentViewController.incident = (Incident *)mapAnnotation.object;
		if (mapAnnotation.pinColor == MKPinAnnotationColorRed) {
			self.viewIncidentViewController.incidents = self.allRows;	
		}
		else {
			self.viewIncidentViewController.incidents = self.pending;
		}
		[self.navigationController pushViewController:self.viewIncidentViewController animated:YES];	
	}
}

- (void)mapView:(MKMapView *)theMapView didUpdateUserLocation:(MKUserLocation *)userLocation {
	[theMapView resizeRegionToFitAllPins:NO animated:YES];
}

#pragma mark -
#pragma mark MKMapViewDelegate

- (void)mapViewDidFailLoadingMap:(MKMapView *)theMapView withError:(NSError *)error {
	DLog(@"error: %@", [error localizedDescription]);
}

#pragma mark -
#pragma mark ItemPickerDelegate
		 
- (void) itemPickerReturned:(ItemPicker *)theItemPicker item:(NSString *)item {
	DLog(@"itemPickerReturned: %@", item);
	if (itemPicker.tag == ItemPickerCategories) {
		self.category = nil;
		for (Category *theCategory in self.categories) {
			if ([theCategory.title isEqualToString:item]) {
				self.category = theCategory;
				DLog(@"Category: %@", theCategory.title);
				break;
			}
		}
		if (self.category != nil) {
			[self setHeader:self.category.title atSection:TableSectionIncidents];
			[self.incidentMapView setLabel:self.category.title];
		}
		else {
			[self setHeader:NSLocalizedString(@"All Categories", nil) atSection:TableSectionIncidents];
			[self.incidentMapView setLabel:NSLocalizedString(@"All Categories", nil)];
		}
		[self filterRows:YES];
		if ([self.filteredRows count] == 0) {
			[self.loadingView showWithMessage:NSLocalizedString(@"No Reports", nil)];
			[self.loadingView hideAfterDelay:1.0];					 
		}	
	}
	else if (itemPicker.tag == ItemPickerUsers) {
		self.user = nil;
		for (User *theUser in self.users) {
			if ([theUser.name isEqualToString:item]) {
				self.user = theUser;
				DLog(@"User: %@", theUser.name);
				break;
			}
		}
		if (self.user != nil) {
			[self.checkinMapView setLabel:[NSString stringWithFormat:@"%@ : %@", NSLocalizedString(@"Checkins", nil), self.user.name]];
		}
		else {
			[self.checkinMapView setLabel:NSLocalizedString(@"All Users", nil)];
		}
		[self.checkinMapView.mapView removeAllPins];
		for (Checkin *checkin in self.checkins) {
			if (self.user == nil || [self.user.identifier isEqualToString:[checkin user]]) {
				[self.checkinMapView.mapView addPinWithTitle:checkin.message 
													subtitle:checkin.dateString 
													latitude:checkin.latitude 
												   longitude:checkin.longitude 
													  object:checkin
													pinColor:MKPinAnnotationColorRed];	
			}
		}
		[self.checkinMapView.mapView resizeRegionToFitAllPins:NO animated:YES];
	}
}

@end
