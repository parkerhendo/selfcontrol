//
//  SCScheduleManager.h
//  SelfControl
//
//  Manages scheduled blocks using launchd LaunchAgents
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kSCScheduleEnabledKey;
extern NSString* const kSCScheduleNameKey;
extern NSString* const kSCScheduleStartTimeKey;
extern NSString* const kSCScheduleDurationKey;
extern NSString* const kSCScheduleDaysOfWeekKey;
extern NSString* const kSCScheduleUUIDKey;

@interface SCScheduleManager : NSObject

+ (instancetype)sharedManager;

// Returns the path to the LaunchAgents directory
+ (NSString*)launchAgentsDirectory;

// Creates or updates a launchd job for the given schedule
- (BOOL)installSchedule:(NSDictionary*)schedule error:(NSError**)error;

// Removes the launchd job for the given schedule UUID
- (BOOL)uninstallScheduleWithUUID:(NSString*)uuid error:(NSError**)error;

// Syncs all schedules from user defaults to launchd
- (BOOL)syncAllSchedules:(NSError**)error;

// Removes all SelfControl schedule jobs
- (BOOL)removeAllSchedules:(NSError**)error;

// Creates a new schedule dictionary with default values
+ (NSMutableDictionary*)newScheduleWithName:(NSString*)name;

// Validates a schedule dictionary
+ (BOOL)validateSchedule:(NSDictionary*)schedule error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
