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

#import "SplashViewController.h"
#import "DeploymentsViewController.h"
#import "IncidentsViewController.h"
#import "ViewIncidentViewController.h"
#import "Settings.h"
#import "NSString+Extension.h"

@interface SplashViewController ()

- (void) pushNextViewController;

@end

@implementation SplashViewController

@synthesize deploymentsViewController, incidentsViewController, viewIncidentViewController;

#pragma mark -
#pragma mark private

- (void) pushNextViewController {
	NSString *lastDeployment = [[Settings sharedSettings] lastDeployment];
	if ([NSString isNilOrEmpty:lastDeployment] == NO) {
		Deployment *deployment = [[Ushahidi sharedUshahidi] getDeploymentWithUrl:lastDeployment];
		if (deployment != nil) {
			[self.navigationController pushViewController:self.deploymentsViewController animated:NO];
			[[Ushahidi sharedUshahidi] loadDeployment:deployment inBackground:NO];
			self.incidentsViewController.deployment = deployment;
			
			NSString *lastIncident = [[Settings sharedSettings] lastIncident];
			if ([NSString isNilOrEmpty:lastIncident] == NO) {
				Incident *incident = [[Ushahidi sharedUshahidi] getIncidentWithIdentifer:lastIncident];
				if (incident != nil) {
					[self.navigationController pushViewController:self.incidentsViewController animated:NO];
					self.viewIncidentViewController.incident = incident;
					self.viewIncidentViewController.incidents = [[Ushahidi sharedUshahidi] getIncidents];
					[self.navigationController pushViewController:self.viewIncidentViewController animated:YES];
				}
				else {
					[self.navigationController pushViewController:self.incidentsViewController animated:YES];
				}
			}
			else {
				[self.navigationController pushViewController:self.incidentsViewController animated:YES];			
			}
		}
		else {
			[self.navigationController pushViewController:self.deploymentsViewController animated:YES];
		}
	}
	else {
		[self.navigationController pushViewController:self.deploymentsViewController animated:YES];
	}	
}

#pragma mark -
#pragma mark UIViewController

- (void)viewDidUnload {
    [super viewDidUnload];
	self.deploymentsViewController = nil;
	self.incidentsViewController = nil;
	self.viewIncidentViewController = nil;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self performSelector:@selector(pushNextViewController) withObject:nil afterDelay:0.0];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
	if (self.navigationController.modalViewController == nil) {
		[self.navigationController setNavigationBarHidden:NO animated:animated];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
	[deploymentsViewController release];
	[incidentsViewController release];
	[viewIncidentViewController release];
    [super dealloc];
}

@end
