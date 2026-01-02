//
//  PreferencesScheduleViewController.m
//  SelfControl
//
//  Schedule management preferences pane
//

#import "PreferencesScheduleViewController.h"
#import "SCScheduleManager.h"
#import "SCUIUtilities.h"

@interface PreferencesScheduleViewController ()
@property (strong) NSMutableArray* schedules;
@property (assign) NSInteger selectedScheduleIndex;
@end

@implementation PreferencesScheduleViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _selectedScheduleIndex = -1;
    }
    return self;
}

- (void)loadView {
    // Create the main view programmatically
    NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 400)];
    self.view = view;

    [self setupUI];
    [self loadSchedules];
}

- (void)setupUI {
    NSView* view = self.view;

    // Title label
    NSTextField* titleLabel = [NSTextField labelWithString:@"Scheduled blocks"];
    titleLabel.font = [NSFont boldSystemFontOfSize:13];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];

    // Schedule table (left side)
    NSScrollView* scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;

    NSTableView* tableView = [[NSTableView alloc] init];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.headerView = nil;
    tableView.rowHeight = 24;

    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    column.width = 180;
    [tableView addTableColumn:column];

    scrollView.documentView = tableView;
    _scheduleTableView = tableView;
    [view addSubview:scrollView];

    // Add/Remove buttons
    NSButton* addBtn = [NSButton buttonWithTitle:@"+" target:self action:@selector(addSchedule:)];
    addBtn.translatesAutoresizingMaskIntoConstraints = NO;
    addBtn.bezelStyle = NSBezelStyleSmallSquare;
    _addButton = addBtn;
    [view addSubview:addBtn];

    NSButton* removeBtn = [NSButton buttonWithTitle:@"-" target:self action:@selector(removeSchedule:)];
    removeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    removeBtn.bezelStyle = NSBezelStyleSmallSquare;
    _removeButton = removeBtn;
    [view addSubview:removeBtn];

    // Right side: schedule details
    NSBox* detailsBox = [[NSBox alloc] init];
    detailsBox.translatesAutoresizingMaskIntoConstraints = NO;
    detailsBox.title = @"Schedule details";
    detailsBox.boxType = NSBoxPrimary;
    [view addSubview:detailsBox];

    NSView* detailsView = [[NSView alloc] init];
    detailsView.translatesAutoresizingMaskIntoConstraints = NO;
    detailsBox.contentView = detailsView;

    // Enabled checkbox
    NSButton* enabledCheck = [NSButton checkboxWithTitle:@"Enabled" target:self action:@selector(schedulePropertyChanged:)];
    enabledCheck.translatesAutoresizingMaskIntoConstraints = NO;
    _enabledCheckbox = enabledCheck;
    [detailsView addSubview:enabledCheck];

    // Name field
    NSTextField* nameLabel = [NSTextField labelWithString:@"Name:"];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [detailsView addSubview:nameLabel];

    NSTextField* nameField = [[NSTextField alloc] init];
    nameField.translatesAutoresizingMaskIntoConstraints = NO;
    nameField.placeholderString = @"Schedule name";
    nameField.target = self;
    nameField.action = @selector(schedulePropertyChanged:);
    _nameField = nameField;
    [detailsView addSubview:nameField];

    // Start time picker
    NSTextField* timeLabel = [NSTextField labelWithString:@"Start time:"];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [detailsView addSubview:timeLabel];

    NSDatePicker* timePicker = [[NSDatePicker alloc] init];
    timePicker.translatesAutoresizingMaskIntoConstraints = NO;
    timePicker.datePickerStyle = NSDatePickerStyleTextField;
    timePicker.datePickerElements = NSDatePickerElementFlagHourMinute;
    timePicker.target = self;
    timePicker.action = @selector(schedulePropertyChanged:);
    _timePicker = timePicker;
    [detailsView addSubview:timePicker];

    // Duration
    NSTextField* durationLabel = [NSTextField labelWithString:@"Duration (min):"];
    durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [detailsView addSubview:durationLabel];

    NSTextField* durationField = [[NSTextField alloc] init];
    durationField.translatesAutoresizingMaskIntoConstraints = NO;
    durationField.target = self;
    durationField.action = @selector(schedulePropertyChanged:);
    _durationField = durationField;
    [detailsView addSubview:durationField];

    NSStepper* stepper = [[NSStepper alloc] init];
    stepper.translatesAutoresizingMaskIntoConstraints = NO;
    stepper.minValue = 1;
    stepper.maxValue = 1440;
    stepper.increment = 15;
    stepper.target = self;
    stepper.action = @selector(durationStepperChanged:);
    _durationStepper = stepper;
    [detailsView addSubview:stepper];

    // Days of week
    NSTextField* daysLabel = [NSTextField labelWithString:@"Days:"];
    daysLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [detailsView addSubview:daysLabel];

    NSStackView* daysStack = [[NSStackView alloc] init];
    daysStack.translatesAutoresizingMaskIntoConstraints = NO;
    daysStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    daysStack.spacing = 4;
    [detailsView addSubview:daysStack];

    NSArray* dayNames = @[@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun"];
    NSMutableArray* dayCheckboxes = [NSMutableArray array];
    for (NSString* day in dayNames) {
        NSButton* cb = [NSButton checkboxWithTitle:day target:self action:@selector(schedulePropertyChanged:)];
        [daysStack addArrangedSubview:cb];
        [dayCheckboxes addObject:cb];
    }
    _mondayCheckbox = dayCheckboxes[0];
    _tuesdayCheckbox = dayCheckboxes[1];
    _wednesdayCheckbox = dayCheckboxes[2];
    _thursdayCheckbox = dayCheckboxes[3];
    _fridayCheckbox = dayCheckboxes[4];
    _saturdayCheckbox = dayCheckboxes[5];
    _sundayCheckbox = dayCheckboxes[6];

    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],

        // Table scroll view
        [scrollView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [scrollView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [scrollView.widthAnchor constraintEqualToConstant:200],
        [scrollView.bottomAnchor constraintEqualToAnchor:addBtn.topAnchor constant:-5],

        // Add/Remove buttons
        [addBtn.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [addBtn.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-20],
        [addBtn.widthAnchor constraintEqualToConstant:25],

        [removeBtn.leadingAnchor constraintEqualToAnchor:addBtn.trailingAnchor constant:2],
        [removeBtn.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-20],
        [removeBtn.widthAnchor constraintEqualToConstant:25],

        // Details box
        [detailsBox.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [detailsBox.leadingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:15],
        [detailsBox.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [detailsBox.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-20],

        // Details view contents
        [enabledCheck.topAnchor constraintEqualToAnchor:detailsView.topAnchor constant:10],
        [enabledCheck.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor constant:10],

        [nameLabel.topAnchor constraintEqualToAnchor:enabledCheck.bottomAnchor constant:15],
        [nameLabel.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor constant:10],

        [nameField.centerYAnchor constraintEqualToAnchor:nameLabel.centerYAnchor],
        [nameField.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:10],
        [nameField.trailingAnchor constraintEqualToAnchor:detailsView.trailingAnchor constant:-10],

        [timeLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:15],
        [timeLabel.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor constant:10],

        [timePicker.centerYAnchor constraintEqualToAnchor:timeLabel.centerYAnchor],
        [timePicker.leadingAnchor constraintEqualToAnchor:timeLabel.trailingAnchor constant:10],

        [durationLabel.topAnchor constraintEqualToAnchor:timeLabel.bottomAnchor constant:15],
        [durationLabel.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor constant:10],

        [durationField.centerYAnchor constraintEqualToAnchor:durationLabel.centerYAnchor],
        [durationField.leadingAnchor constraintEqualToAnchor:durationLabel.trailingAnchor constant:10],
        [durationField.widthAnchor constraintEqualToConstant:60],

        [stepper.centerYAnchor constraintEqualToAnchor:durationField.centerYAnchor],
        [stepper.leadingAnchor constraintEqualToAnchor:durationField.trailingAnchor constant:5],

        [daysLabel.topAnchor constraintEqualToAnchor:durationLabel.bottomAnchor constant:15],
        [daysLabel.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor constant:10],

        [daysStack.topAnchor constraintEqualToAnchor:daysLabel.bottomAnchor constant:5],
        [daysStack.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor constant:10],
    ]];

    [self updateDetailsViewEnabled:NO];
}

- (void)loadSchedules {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSArray* savedSchedules = [defaults arrayForKey:@"Schedules"];
    self.schedules = savedSchedules ? [savedSchedules mutableCopy] : [NSMutableArray array];
    [self.scheduleTableView reloadData];
}

- (void)saveSchedules {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.schedules forKey:@"Schedules"];
    [defaults synchronize];

    // Sync to launchd
    NSError* error;
    [[SCScheduleManager sharedManager] syncAllSchedules:&error];
    if (error) {
        NSLog(@"Failed to sync schedules: %@", error);
    }
}

- (void)updateDetailsViewEnabled:(BOOL)enabled {
    self.enabledCheckbox.enabled = enabled;
    self.nameField.enabled = enabled;
    self.timePicker.enabled = enabled;
    self.durationField.enabled = enabled;
    self.durationStepper.enabled = enabled;
    self.mondayCheckbox.enabled = enabled;
    self.tuesdayCheckbox.enabled = enabled;
    self.wednesdayCheckbox.enabled = enabled;
    self.thursdayCheckbox.enabled = enabled;
    self.fridayCheckbox.enabled = enabled;
    self.saturdayCheckbox.enabled = enabled;
    self.sundayCheckbox.enabled = enabled;
    self.removeButton.enabled = enabled;

    if (!enabled) {
        self.nameField.stringValue = @"";
        self.durationField.stringValue = @"";
        self.enabledCheckbox.state = NSControlStateValueOff;
        self.mondayCheckbox.state = NSControlStateValueOff;
        self.tuesdayCheckbox.state = NSControlStateValueOff;
        self.wednesdayCheckbox.state = NSControlStateValueOff;
        self.thursdayCheckbox.state = NSControlStateValueOff;
        self.fridayCheckbox.state = NSControlStateValueOff;
        self.saturdayCheckbox.state = NSControlStateValueOff;
        self.sundayCheckbox.state = NSControlStateValueOff;
    }
}

- (void)populateDetailsFromSchedule:(NSDictionary*)schedule {
    self.enabledCheckbox.state = [schedule[kSCScheduleEnabledKey] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.nameField.stringValue = schedule[kSCScheduleNameKey] ?: @"";

    // Parse time string to date
    NSString* timeStr = schedule[kSCScheduleStartTimeKey];
    if (timeStr) {
        NSArray* parts = [timeStr componentsSeparatedByString:@":"];
        NSDateComponents* comps = [[NSDateComponents alloc] init];
        comps.hour = [parts[0] integerValue];
        comps.minute = [parts[1] integerValue];
        NSCalendar* cal = [NSCalendar currentCalendar];
        NSDate* date = [cal dateFromComponents:comps];
        self.timePicker.dateValue = date ?: [NSDate date];
    }

    NSInteger duration = [schedule[kSCScheduleDurationKey] integerValue];
    self.durationField.stringValue = [NSString stringWithFormat:@"%ld", (long)duration];
    self.durationStepper.integerValue = duration;

    NSArray* days = schedule[kSCScheduleDaysOfWeekKey];
    self.mondayCheckbox.state = [days containsObject:@1] ? NSControlStateValueOn : NSControlStateValueOff;
    self.tuesdayCheckbox.state = [days containsObject:@2] ? NSControlStateValueOn : NSControlStateValueOff;
    self.wednesdayCheckbox.state = [days containsObject:@3] ? NSControlStateValueOn : NSControlStateValueOff;
    self.thursdayCheckbox.state = [days containsObject:@4] ? NSControlStateValueOn : NSControlStateValueOff;
    self.fridayCheckbox.state = [days containsObject:@5] ? NSControlStateValueOn : NSControlStateValueOff;
    self.saturdayCheckbox.state = [days containsObject:@6] ? NSControlStateValueOn : NSControlStateValueOff;
    self.sundayCheckbox.state = [days containsObject:@7] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSMutableDictionary*)scheduleFromDetails {
    NSMutableDictionary* schedule = [NSMutableDictionary dictionary];

    schedule[kSCScheduleEnabledKey] = @(self.enabledCheckbox.state == NSControlStateValueOn);
    schedule[kSCScheduleNameKey] = self.nameField.stringValue;

    // Format time
    NSCalendar* cal = [NSCalendar currentCalendar];
    NSDateComponents* comps = [cal components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:self.timePicker.dateValue];
    schedule[kSCScheduleStartTimeKey] = [NSString stringWithFormat:@"%02ld:%02ld", (long)comps.hour, (long)comps.minute];

    schedule[kSCScheduleDurationKey] = @(self.durationField.integerValue);

    // Days
    NSMutableArray* days = [NSMutableArray array];
    if (self.mondayCheckbox.state == NSControlStateValueOn) [days addObject:@1];
    if (self.tuesdayCheckbox.state == NSControlStateValueOn) [days addObject:@2];
    if (self.wednesdayCheckbox.state == NSControlStateValueOn) [days addObject:@3];
    if (self.thursdayCheckbox.state == NSControlStateValueOn) [days addObject:@4];
    if (self.fridayCheckbox.state == NSControlStateValueOn) [days addObject:@5];
    if (self.saturdayCheckbox.state == NSControlStateValueOn) [days addObject:@6];
    if (self.sundayCheckbox.state == NSControlStateValueOn) [days addObject:@7];
    schedule[kSCScheduleDaysOfWeekKey] = days;

    return schedule;
}

#pragma mark - Actions

- (IBAction)addSchedule:(id)sender {
    NSMutableDictionary* newSchedule = [SCScheduleManager newScheduleWithName:@"New schedule"];
    [self.schedules addObject:newSchedule];
    [self.scheduleTableView reloadData];
    [self saveSchedules];

    // Select the new schedule
    NSInteger newIndex = self.schedules.count - 1;
    [self.scheduleTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newIndex] byExtendingSelection:NO];
}

- (IBAction)removeSchedule:(id)sender {
    if (self.selectedScheduleIndex < 0 || self.selectedScheduleIndex >= self.schedules.count) return;

    NSDictionary* schedule = self.schedules[self.selectedScheduleIndex];
    NSString* uuid = schedule[kSCScheduleUUIDKey];

    // Remove from launchd
    [[SCScheduleManager sharedManager] uninstallScheduleWithUUID:uuid error:nil];

    // Remove from array
    [self.schedules removeObjectAtIndex:self.selectedScheduleIndex];
    [self.scheduleTableView reloadData];
    [self saveSchedules];

    self.selectedScheduleIndex = -1;
    [self updateDetailsViewEnabled:NO];
}

- (IBAction)schedulePropertyChanged:(id)sender {
    if (self.selectedScheduleIndex < 0 || self.selectedScheduleIndex >= self.schedules.count) return;

    NSMutableDictionary* updatedSchedule = [self scheduleFromDetails];

    // Preserve UUID
    NSDictionary* oldSchedule = self.schedules[self.selectedScheduleIndex];
    updatedSchedule[kSCScheduleUUIDKey] = oldSchedule[kSCScheduleUUIDKey];

    self.schedules[self.selectedScheduleIndex] = updatedSchedule;
    [self.scheduleTableView reloadData];
    [self saveSchedules];
}

- (IBAction)durationStepperChanged:(id)sender {
    self.durationField.integerValue = self.durationStepper.integerValue;
    [self schedulePropertyChanged:sender];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    return self.schedules.count;
}

#pragma mark - NSTableViewDelegate

- (NSView*)tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    NSTableCellView* cell = [tableView makeViewWithIdentifier:@"cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = @"cell";

        NSTextField* tf = [NSTextField labelWithString:@""];
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:tf];
        cell.textField = tf;

        [NSLayoutConstraint activateConstraints:@[
            [tf.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:5],
            [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-5],
            [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }

    NSDictionary* schedule = self.schedules[row];
    NSString* name = schedule[kSCScheduleNameKey];
    BOOL enabled = [schedule[kSCScheduleEnabledKey] boolValue];

    cell.textField.stringValue = name;
    cell.textField.textColor = enabled ? [NSColor labelColor] : [NSColor secondaryLabelColor];

    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification {
    NSInteger row = self.scheduleTableView.selectedRow;
    self.selectedScheduleIndex = row;

    if (row >= 0 && row < self.schedules.count) {
        [self updateDetailsViewEnabled:YES];
        [self populateDetailsFromSchedule:self.schedules[row]];
    } else {
        [self updateDetailsViewEnabled:NO];
    }
}

#pragma mark - MASPreferencesViewController

- (NSString*)viewIdentifier {
    return @"SchedulePreferences";
}

- (NSString*)identifier {
    return @"SchedulePreferences";
}

- (NSImage*)toolbarItemImage {
    return [NSImage imageNamed:NSImageNameAdvanced];
}

- (NSString*)toolbarItemLabel {
    return NSLocalizedString(@"Schedule", @"Toolbar item name for the Schedule preference pane");
}

@end
