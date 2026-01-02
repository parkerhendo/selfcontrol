//
//  PreferencesScheduleViewController.h
//  SelfControl
//
//  Schedule management preferences pane
//

#import <Cocoa/Cocoa.h>
#import <MASPreferences/MASPreferencesViewController.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesScheduleViewController : NSViewController <MASPreferencesViewController, NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView* scheduleTableView;
@property (weak) IBOutlet NSButton* addButton;
@property (weak) IBOutlet NSButton* removeButton;
@property (weak) IBOutlet NSTextField* nameField;
@property (weak) IBOutlet NSDatePicker* timePicker;
@property (weak) IBOutlet NSTextField* durationField;
@property (weak) IBOutlet NSStepper* durationStepper;
@property (weak) IBOutlet NSButton* enabledCheckbox;

// Day checkboxes
@property (weak) IBOutlet NSButton* mondayCheckbox;
@property (weak) IBOutlet NSButton* tuesdayCheckbox;
@property (weak) IBOutlet NSButton* wednesdayCheckbox;
@property (weak) IBOutlet NSButton* thursdayCheckbox;
@property (weak) IBOutlet NSButton* fridayCheckbox;
@property (weak) IBOutlet NSButton* saturdayCheckbox;
@property (weak) IBOutlet NSButton* sundayCheckbox;

- (IBAction)addSchedule:(id)sender;
- (IBAction)removeSchedule:(id)sender;
- (IBAction)schedulePropertyChanged:(id)sender;
- (IBAction)durationStepperChanged:(id)sender;

@end

NS_ASSUME_NONNULL_END
