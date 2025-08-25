/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSBrowserCell.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSSlider.h>

#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/NXTNumericField.h>
#import <DesktopKit/NXTCountdownAlert.h>

#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEDisplay.h>

#import <dispatch/dispatch.h>

#import "AppController.h"
#import "Display.h"

@implementation DisplayPrefs

//
#pragma mark - Init & protocol
//

- (id)init
{
  NSBundle *bundle;
  NSString *imagePath;

  self = [super init];

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"Monitor" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  lastGoodResolution = [NSMutableDictionary new];

  return self;
}

- (void)dealloc
{
  NSLog(@"DisplayPrefs -dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter notificationCenterForType:GSPublicNotificationCenterType] removeObserver:self];

  [image release];

  [view release];
  [systemScreen release];
  if (saveConfigTimer) {
    [saveConfigTimer release];
  }
  [lastGoodResolution release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  systemScreen = [OSEScreen sharedScreen];
  [systemScreen retain];
  [systemScreen setUseAutosave:YES];

  // Setup NXNumericField float constraints
  [gammaField setMinimumValue:0.1];
  [gammaField setMaximumValue:2.0];
  [[gammaField formatter] setMinimumIntegerDigits:1];
  [[gammaField formatter] setMinimumFractionDigits:2];

  // Setup NXNumericField integer constraints
  [brightnessField setMinimumValue:0.5];
  [brightnessField setMaximumValue:100.0];

  [monitorsList loadColumnZero];
  [self selectFirstEnabledMonitor];

  [rotationBtn setEnabled:NO];
  [reflectionBtn setEnabled:NO];

  // Desktop background
  CGFloat red, green, blue;
  if ([systemScreen backgroundColorRed:&red green:&green blue:&blue] == YES) {
    desktopBackground = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:1.0];
    [colorBtn setColor:desktopBackground];
    [systemScreen setBackgroundColorRed:red green:green blue:blue];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenDidUpdate:)
                                               name:OSEScreenDidUpdateNotification
                                             object:systemScreen];
  [[NSDistributedNotificationCenter notificationCenterForType:GSPublicNotificationCenterType]
      addObserver:self
         selector:@selector(screenDidChange:)
             name:OSEScreenDidChangeNotification
           object:nil];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Display" owner:self]) {
      NSLog(@"Display.preferences: Could not load NIB, aborting.");
      return nil;
    }
  }

  return view;
}

- (NSString *)buttonCaption
{
  return @"Display Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
#pragma mark - Helper methods
//
- (void)fillRateButton
{
  NSString *resBtnTitle;
  NSString *rateTitle;
  NSString *resolutionTitle;
  NSDictionary *res;
  double rateValue = 0.0;
  NSString *rateFormat = @"%.2f Hz";

  [rateBtn removeAllItems];

  // Fill the buttion with items
  resBtnTitle = [resolutionBtn titleOfSelectedItem];
  for (res in [selectedDisplay allResolutions]) {
    resolutionTitle = [res objectForKey:OSEDisplayResolutionNameKey];
    if ([resolutionTitle isEqualToString:resBtnTitle]) {
      rateValue = [[res objectForKey:OSEDisplayResolutionRateKey] doubleValue];
      rateTitle = [NSString stringWithFormat:rateFormat, rateValue];
      [rateBtn addItemWithTitle:rateTitle];
      [[rateBtn itemWithTitle:rateTitle] setRepresentedObject:res];
    }
  }
}

- (void)updateRateButton
{
  NSString *rateTitle;

  if ([[rateBtn itemArray] count] == 1) {
    [rateBtn setEnabled:NO];
  } else {
    rateTitle = [NSString stringWithFormat:@"%.2f Hz", selectedDisplay.activeRate];
    [rateBtn selectItemWithTitle:rateTitle];
    [rateBtn setEnabled:YES];
  }  
}

- (void)setResolution
{
  NSDictionary *activeResolution;
  NSString *resolution;
  NSDictionary *targetResolution = [[rateBtn selectedCell] representedObject];

  if (targetResolution == nil) {
    NSLog(@"%s - resolution dictionary is nil! Resolution button is %@", __func__,
          [resolutionBtn title]);
    return;
  }

  // Save current resolution
  activeResolution = [selectedDisplay activeResolution];
  resolution = [activeResolution objectForKey:OSEDisplayResolutionNameKey];
  NSLog(@"%s: saving last good resolution - %@", __func__, resolution);
  [lastGoodResolution setObject:[selectedDisplay activeResolution]
                         forKey:[selectedDisplay outputName]];
        
  // Set resolution only to active display.
  // Display activating implemented in 'Screen' Preferences' module.
  if ([selectedDisplay isActive]) {
    // NSLog(@"%s - %@", __func__, [[rateBtn selectedCell] representedObject]);
    [systemScreen setDisplay:selectedDisplay resolution:[[rateBtn selectedCell] representedObject]];
  }
}

- (void)selectFirstEnabledMonitor
{
  NSArray *cells = [[monitorsList matrixInColumn:0] cells];

  for (int i = 0; i < [cells count]; i++) {
    if ([[cells objectAtIndex:i] isEnabled] == YES) {
      [monitorsList selectRow:i inColumn:0];
      break;
    }
  }

  [self monitorsListClicked:monitorsList];
}

- (void)saveDisplayConfig
{
  NSLog(@"Display: save current Display.confg");
  [systemScreen saveCurrentDisplayLayout];
}

//
#pragma mark - Action methods
//
- (IBAction)monitorsListClicked:(id)sender
{
  NSString *resolution;
  NSDictionary *resolutionDesc;

  selectedDisplay = [[sender selectedCell] representedObject];
  // NSLog(@"Display.preferences: selected monitor with title: %@", mName);

  // Resolution
  [resolutionBtn removeAllItems];
  for (NSDictionary *res in [selectedDisplay allResolutions]) {
    resolution = [res objectForKey:OSEDisplayResolutionNameKey];
    [resolutionBtn addItemWithTitle:resolution];
  }
  resolutionDesc = [selectedDisplay activeResolution];
  resolution = [resolutionDesc objectForKey:OSEDisplayResolutionNameKey];
  [resolutionBtn selectItemWithTitle:resolution];
  // Rate button filled here. Items tagged with resolution description object
  [self fillRateButton];
  [self updateRateButton];

  if ([selectedDisplay isGammaSupported] == YES) {
    [gammaSlider setEnabled:YES];
    [gammaField setEnabled:YES];
    [brightnessSlider setEnabled:YES];
    [brightnessField setEnabled:YES];
    // Contrast
    NSString *gammaString = [NSString stringWithFormat:@"%.2f", [selectedDisplay gamma]];
    [gammaSlider setFloatValue:[gammaString floatValue]];
    [gammaField setStringValue:gammaString];

    // Brightness
    CGFloat brightness = [selectedDisplay gammaBrightness];
    [brightnessSlider setFloatValue:brightness * 100];
    [brightnessField setStringValue:[NSString stringWithFormat:@"%.0f", brightness * 100]];
  } else {
    [gammaSlider setEnabled:NO];
    [gammaField setEnabled:NO];
    [brightnessSlider setEnabled:NO];
    [brightnessField setEnabled:NO];
  }
}

- (IBAction)resolutionClicked:(id)sender
{
  [self fillRateButton];
  [self setResolution];
  [self updateRateButton];
}

- (IBAction)rateClicked:(id)sender
{
  [self setResolution];
}

- (IBAction)sliderMoved:(id)sender
{
  CGFloat value = [sender floatValue];

  if (saveConfigTimer && [saveConfigTimer isValid]) {
    [saveConfigTimer invalidate];
  }
  saveConfigTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                     target:self
                                                   selector:@selector(saveDisplayConfig)
                                                   userInfo:nil
                                                    repeats:NO];
  [saveConfigTimer retain];

  if (sender == gammaSlider) {
    // NSLog(@"Gamma slider moved");
    [gammaField setStringValue:[NSString stringWithFormat:@"%.2f", value]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      [selectedDisplay setGamma:value];
    });
  } else if (sender == brightnessSlider) {
    // NSLog(@"Brightness slider moved");
    // if (value > 1.0) value = 1.0;
    [brightnessField setIntValue:[sender intValue]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      [selectedDisplay setGammaBrightness:value / 100];
    });
  } else {
    NSLog(@"Unknown slider moved");
  }
}

- (IBAction)backgroundChanged:(id)sender
{
  NSColor *color = [sender color];
  NSColor *rgbColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];

  // NSLog(@"Display: backgroundChanged: %@", [sender className]);
  if ([systemScreen setBackgroundColorRed:[rgbColor redComponent]
                                    green:[rgbColor greenComponent]
                                     blue:[rgbColor blueComponent]] == YES) {
    OSEDefaults *defs = [OSEDefaults globalUserDefaults];
    NSDictionary *dBack;

    dBack = @{
      @"Red" : [NSNumber numberWithFloat:[color redComponent]],
      @"Green" : [NSNumber numberWithFloat:[color greenComponent]],
      @"Blue" : [NSNumber numberWithFloat:[color blueComponent]],
      @"Alpha" : [NSNumber numberWithFloat:1.0]
    };
    [defs setObject:dBack forKey:OSEDesktopBackgroundColor];
  }
}

//
#pragma mark - Browser delegate (monitors list)
//
- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column
{
  if (column > 0)
    return @"";

  return @"Monitors";
}

- (void)browser:(NSBrowser *)sender
    createRowsForColumn:(NSInteger)column
               inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *bc;

  if (column > 0)
    return;

  for (OSEDisplay *d in [systemScreen connectedDisplays]) {
    [matrix addRow];
    bc = [matrix cellAtRow:[matrix numberOfRows] - 1 column:0];
    [bc setTitle:[d outputName]];
    [bc setRepresentedObject:d];
    [bc setLeaf:YES];
    [bc setRefusesFirstResponder:YES];
    [bc setEnabled:[d isActive]];
  }
}

//
#pragma mark - TextField Delegate
//
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  id tf = [aNotification object];
  CGFloat value = [tf floatValue];

  NSLog(@"Display set gamma: %f", value);

  if (tf == gammaField) {
    [gammaSlider setFloatValue:value];
    [selectedDisplay setGamma:value];
    [tf setFloatValue:value];
  } else if (tf == brightnessField) {
    [selectedDisplay setGammaBrightness:value / 100];
    value = [selectedDisplay gammaBrightness] * 100;
    [brightnessSlider setFloatValue:value];
    // [tf setIntValue:[strVal intValue]];
    [tf setFloatValue:value];
  }

  // Changes to gamma is not generate XRRScreenChangeNotify event.
  // That's why saving display configuration is here.
  [systemScreen saveCurrentDisplayLayout];
}

// Notifications
- (void)screenDidUpdate:(NSNotification *)aNotif
{
  NSLog(@"%s: XRandR screen resources was updated, refreshing...", __func__);
  [monitorsList reloadColumn:0];
  [self selectFirstEnabledMonitor];
}

- (void)screenDidChange:(NSNotification *)aNotif
{
  NXTCountdownAlert *alert;

  NSLog(@"%s: Received ScreenDidChange notification ", __func__);
  
  alert =
      [[NXTCountdownAlert alloc] initWithTitle:@"Display resolution"
                                       message:@"Do you want to keep current display resolution?\n"
                                                "Resolution will be reverted in %i seconds."
                                 defaultButton:@"Revert"
                               alternateButton:@"Keep"
                                   otherButton:nil];
  [alert setCountDownPeriod:5];

  if ([alert runModal] == NSAlertDefaultReturn) {
    NSLog(@"Revert resoltuion to previous.");
  } else {
    NSLog(@"Keep current resoltuion.");
  }
  [alert release];
}


@end
