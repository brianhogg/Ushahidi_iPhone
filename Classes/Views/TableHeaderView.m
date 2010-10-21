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

#import "TableHeaderView.h"

@implementation TableHeaderView

+ (id)headerForTable:(UITableView *)tableView text:(NSString *)text {
	return [[[TableHeaderView alloc] initForTable:tableView text:text textColor:[UIColor whiteColor] backgroundColor:[UIColor blackColor]] autorelease];
}

+ (id)headerForTable:(UITableView *)tableView text:(NSString *)text textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor {
	return [[[TableHeaderView alloc] initForTable:tableView text:text textColor:textColor backgroundColor:backgroundColor] autorelease];
}

- (id)initForTable:(UITableView *)tableView text:(NSString *)theText textColor:(UIColor *)theTextColor backgroundColor:(UIColor *)theBackgroundColor {
	CGRect theFrame = CGRectMake(0.0, 0.0, tableView.bounds.size.width, 24.0);
    if (self = [super initWithFrame:theFrame]) {
		self.backgroundColor = theBackgroundColor;
		self.opaque = YES;
		
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.backgroundColor = [UIColor clearColor];
		label.opaque = YES;
		label.textColor = theTextColor;
		label.font = [UIFont boldSystemFontOfSize:14];
		label.frame = CGRectMake(10.0, 0.0, theFrame.size.width - 10.0, theFrame.size.height);
		label.text = theText;
		
		[self addSubview:label];
		[label release];
	}
    return self;
}

- (void)dealloc {
	[super dealloc];
}

- (void) setText:(NSString *)text {
	UILabel *label = (UILabel *)[self.subviews objectAtIndex:0];
	if (label != nil && [label isKindOfClass:[UILabel class]]) {
		[label setText:text];
	}
}

@end