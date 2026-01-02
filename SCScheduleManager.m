//
//  SCScheduleManager.m
//  SelfControl
//
//  Manages scheduled blocks using launchd LaunchAgents
//

#import "SCScheduleManager.h"
#import "SCSettings.h"

NSString* const kSCScheduleEnabledKey = @"enabled";
NSString* const kSCScheduleNameKey = @"name";
NSString* const kSCScheduleStartTimeKey = @"startTime";
NSString* const kSCScheduleDurationKey = @"duration";
NSString* const kSCScheduleDaysOfWeekKey = @"daysOfWeek";
NSString* const kSCScheduleUUIDKey = @"uuid";

static NSString* const kLaunchAgentPrefix = @"org.eyebeam.SelfControl.Schedule.";

@implementation SCScheduleManager

+ (instancetype)sharedManager {
    static SCScheduleManager* sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[SCScheduleManager alloc] init];
    });
    return sharedManager;
}

+ (NSString*)launchAgentsDirectory {
    NSString* homeDir = NSHomeDirectory();
    return [homeDir stringByAppendingPathComponent:@"Library/LaunchAgents"];
}

+ (NSString*)plistPathForUUID:(NSString*)uuid {
    NSString* filename = [NSString stringWithFormat:@"%@%@.plist", kLaunchAgentPrefix, uuid];
    return [[self launchAgentsDirectory] stringByAppendingPathComponent:filename];
}

+ (NSString*)launchAgentLabelForUUID:(NSString*)uuid {
    return [NSString stringWithFormat:@"%@%@", kLaunchAgentPrefix, uuid];
}

- (BOOL)installSchedule:(NSDictionary*)schedule error:(NSError**)error {
    if (![SCScheduleManager validateSchedule:schedule error:error]) {
        return NO;
    }

    NSString* uuid = schedule[kSCScheduleUUIDKey];
    BOOL enabled = [schedule[kSCScheduleEnabledKey] boolValue];

    // If disabled, just uninstall any existing job
    if (!enabled) {
        return [self uninstallScheduleWithUUID:uuid error:error];
    }

    // Parse start time (HH:mm format)
    NSString* startTime = schedule[kSCScheduleStartTimeKey];
    NSArray* timeParts = [startTime componentsSeparatedByString:@":"];
    NSInteger hour = [timeParts[0] integerValue];
    NSInteger minute = [timeParts[1] integerValue];

    // Get days of week (1=Mon through 7=Sun in our format, but launchd uses 0=Sun through 6=Sat)
    NSArray<NSNumber*>* daysOfWeek = schedule[kSCScheduleDaysOfWeekKey];
    NSMutableArray<NSNumber*>* launchdDays = [NSMutableArray array];
    for (NSNumber* day in daysOfWeek) {
        // Convert from ISO 8601 (1=Mon, 7=Sun) to launchd format (0=Sun, 6=Sat)
        NSInteger isoDay = [day integerValue];
        NSInteger launchdDay = (isoDay % 7); // 7 (Sun) becomes 0, 1 (Mon) becomes 1, etc.
        [launchdDays addObject:@(launchdDay)];
    }

    // Duration in minutes
    NSInteger durationMinutes = [schedule[kSCScheduleDurationKey] integerValue];

    // Get path to the CLI tool
    NSString* cliPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/selfcontrol-cli"];

    // Calculate block end date from now + duration (launchd will run this at the scheduled time)
    // The CLI will read blocklist from user defaults if --blocklist is not specified
    NSString* scriptContent = [NSString stringWithFormat:
        @"#!/bin/bash\n"
        @"# SelfControl scheduled block - %@\n"
        @"# Triggered by launchd at scheduled time\n"
        @"\n"
        @"DURATION_SECS=%ld\n"
        @"END_DATE=$(date -u -v+${DURATION_SECS}S '+%%Y-%%m-%%dT%%H:%%M:%%SZ')\n"
        @"\n"
        @"echo \"$(date): Starting scheduled SelfControl block until $END_DATE\"\n"
        @"\n"
        @"# Start the block - CLI reads blocklist from user defaults\n"
        @"\"%@\" start --enddate \"$END_DATE\"\n"
        @"\n"
        @"echo \"$(date): Block command completed with exit code $?\"\n",
        schedule[kSCScheduleNameKey],
        (long)(durationMinutes * 60),
        cliPath
    ];

    // Write the shell script
    NSString* scriptDir = [[SCScheduleManager launchAgentsDirectory] stringByAppendingPathComponent:@"SelfControlScripts"];
    NSFileManager* fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:scriptDir]) {
        [fm createDirectoryAtPath:scriptDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString* scriptPath = [scriptDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sh", uuid]];
    [scriptContent writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:error];

    // Make script executable
    NSDictionary* attrs = @{NSFilePosixPermissions: @0755};
    [fm setAttributes:attrs ofItemAtPath:scriptPath error:nil];

    // Build the launchd plist
    NSMutableDictionary* plist = [NSMutableDictionary dictionary];
    plist[@"Label"] = [SCScheduleManager launchAgentLabelForUUID:uuid];
    plist[@"ProgramArguments"] = @[@"/bin/bash", scriptPath];
    plist[@"RunAtLoad"] = @NO;

    // Build calendar interval(s) for each day
    NSMutableArray* calendarIntervals = [NSMutableArray array];
    for (NSNumber* day in launchdDays) {
        [calendarIntervals addObject:@{
            @"Weekday": day,
            @"Hour": @(hour),
            @"Minute": @(minute)
        }];
    }
    plist[@"StartCalendarInterval"] = calendarIntervals;

    // Standard output/error logging
    NSString* logDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/SelfControl"];
    if (![fm fileExistsAtPath:logDir]) {
        [fm createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    plist[@"StandardOutPath"] = [logDir stringByAppendingPathComponent:[NSString stringWithFormat:@"schedule-%@.log", uuid]];
    plist[@"StandardErrorPath"] = [logDir stringByAppendingPathComponent:[NSString stringWithFormat:@"schedule-%@.error.log", uuid]];

    // Ensure LaunchAgents directory exists
    NSString* launchAgentsDir = [SCScheduleManager launchAgentsDirectory];
    if (![fm fileExistsAtPath:launchAgentsDir]) {
        [fm createDirectoryAtPath:launchAgentsDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // Write the plist
    NSString* plistPath = [SCScheduleManager plistPathForUUID:uuid];

    // First unload any existing job
    [self unloadLaunchAgentAtPath:plistPath];

    BOOL written = [plist writeToFile:plistPath atomically:YES];
    if (!written) {
        if (error) {
            *error = [NSError errorWithDomain:@"SelfControl" code:500 userInfo:@{
                NSLocalizedDescriptionKey: @"Failed to write schedule plist"
            }];
        }
        return NO;
    }

    // Load the new job
    return [self loadLaunchAgentAtPath:plistPath error:error];
}

- (BOOL)uninstallScheduleWithUUID:(NSString*)uuid error:(NSError**)error {
    NSString* plistPath = [SCScheduleManager plistPathForUUID:uuid];
    NSFileManager* fm = [NSFileManager defaultManager];

    // Unload first
    [self unloadLaunchAgentAtPath:plistPath];

    // Remove plist file
    if ([fm fileExistsAtPath:plistPath]) {
        NSError* removeError;
        if (![fm removeItemAtPath:plistPath error:&removeError]) {
            if (error) *error = removeError;
            return NO;
        }
    }

    // Remove script file
    NSString* scriptDir = [[SCScheduleManager launchAgentsDirectory] stringByAppendingPathComponent:@"SelfControlScripts"];
    NSString* scriptPath = [scriptDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sh", uuid]];
    if ([fm fileExistsAtPath:scriptPath]) {
        [fm removeItemAtPath:scriptPath error:nil];
    }

    return YES;
}

- (BOOL)syncAllSchedules:(NSError**)error {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSArray* schedules = [defaults arrayForKey:@"Schedules"];

    // Track which UUIDs we have schedules for
    NSMutableSet* activeUUIDs = [NSMutableSet set];

    for (NSDictionary* schedule in schedules) {
        NSString* uuid = schedule[kSCScheduleUUIDKey];
        if (uuid) {
            [activeUUIDs addObject:uuid];
            if (![self installSchedule:schedule error:error]) {
                NSLog(@"Failed to install schedule %@: %@", schedule[kSCScheduleNameKey], *error);
            }
        }
    }

    // Remove any orphaned schedule jobs
    [self removeOrphanedSchedulesExcept:activeUUIDs];

    return YES;
}

- (void)removeOrphanedSchedulesExcept:(NSSet*)activeUUIDs {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* launchAgentsDir = [SCScheduleManager launchAgentsDirectory];
    NSArray* files = [fm contentsOfDirectoryAtPath:launchAgentsDir error:nil];

    for (NSString* filename in files) {
        if ([filename hasPrefix:kLaunchAgentPrefix] && [filename hasSuffix:@".plist"]) {
            // Extract UUID from filename
            NSString* withoutPrefix = [filename substringFromIndex:kLaunchAgentPrefix.length];
            NSString* uuid = [withoutPrefix stringByReplacingOccurrencesOfString:@".plist" withString:@""];

            if (![activeUUIDs containsObject:uuid]) {
                [self uninstallScheduleWithUUID:uuid error:nil];
            }
        }
    }
}

- (BOOL)removeAllSchedules:(NSError**)error {
    return [self syncAllSchedules:error]; // With empty schedules array, this removes all
}

- (BOOL)loadLaunchAgentAtPath:(NSString*)path error:(NSError**)error {
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments = @[@"load", path];

    NSPipe* pipe = [NSPipe pipe];
    task.standardError = pipe;

    [task launch];
    [task waitUntilExit];

    if (task.terminationStatus != 0) {
        NSData* errData = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
        if (error) {
            *error = [NSError errorWithDomain:@"SelfControl" code:501 userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to load schedule: %@", errStr]
            }];
        }
        return NO;
    }
    return YES;
}

- (void)unloadLaunchAgentAtPath:(NSString*)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;

    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments = @[@"unload", path];
    [task launch];
    [task waitUntilExit];
}

+ (NSMutableDictionary*)newScheduleWithName:(NSString*)name {
    return [@{
        kSCScheduleEnabledKey: @YES,
        kSCScheduleNameKey: name ?: @"New schedule",
        kSCScheduleStartTimeKey: @"09:00",
        kSCScheduleDurationKey: @60,
        kSCScheduleDaysOfWeekKey: @[@1, @2, @3, @4, @5], // Mon-Fri
        kSCScheduleUUIDKey: [[NSUUID UUID] UUIDString]
    } mutableCopy];
}

+ (BOOL)validateSchedule:(NSDictionary*)schedule error:(NSError**)error {
    if (!schedule[kSCScheduleUUIDKey]) {
        if (error) {
            *error = [NSError errorWithDomain:@"SelfControl" code:400 userInfo:@{
                NSLocalizedDescriptionKey: @"Schedule missing UUID"
            }];
        }
        return NO;
    }

    NSString* startTime = schedule[kSCScheduleStartTimeKey];
    if (!startTime || ![startTime containsString:@":"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"SelfControl" code:401 userInfo:@{
                NSLocalizedDescriptionKey: @"Invalid start time format"
            }];
        }
        return NO;
    }

    NSArray* daysOfWeek = schedule[kSCScheduleDaysOfWeekKey];
    if (!daysOfWeek || daysOfWeek.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"SelfControl" code:402 userInfo:@{
                NSLocalizedDescriptionKey: @"No days selected"
            }];
        }
        return NO;
    }

    NSInteger duration = [schedule[kSCScheduleDurationKey] integerValue];
    if (duration < 1) {
        if (error) {
            *error = [NSError errorWithDomain:@"SelfControl" code:403 userInfo:@{
                NSLocalizedDescriptionKey: @"Duration must be at least 1 minute"
            }];
        }
        return NO;
    }

    return YES;
}

@end
