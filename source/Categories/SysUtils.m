/*
    SysUtils.m

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>
#import <Foundation/NSCharacterSet.h>

#import "SystemIncludes.h"  // for UTF8STRING()
#import "SysUtils.h"

static NSString *const kPathExtensionFramework = @"framework";
static NSString *const kPathExtensionPlatform = @"platform";
static NSString *const kPathExtensionApp = @"app";

BOOL excluded(NSString *extension) {
    NSArray *excluded = @[kPathExtensionApp, kPathExtensionPlatform, kPathExtensionFramework];
    
    BOOL result = NO;
    for (NSString *excludedExtension in excluded) {
        if ([excludedExtension isEqualToString:extension]) {
            result = YES;
            break;
        }
    }
    
    return result;
}

NSString *search(NSString *path, NSString *target, BOOL *stop) {
    if (*stop == YES) { return nil; }
    if ([path.lastPathComponent isEqualToString:target]) { *stop = YES; return [path.copy autorelease]; }
    if (excluded(path.lastPathComponent.pathExtension)) { return nil; }
    
    
    NSError *error = nil;
    NSArray *folderItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    
    NSString *result = nil;
    for (NSString *item in folderItems) {
        NSString *currentPath = [path stringByAppendingPathComponent:item];
        result = search(currentPath, target, stop);
        
        if (result != nil) {
            *stop = YES;
            return result;
        }
    }
    
    return result;
}

NSString *searchForFile(NSString *path, NSString *target) {
    BOOL stop = NO;

    NSString *toolPath = search(path, target, &stop);
    
    return toolPath;
}


@implementation NSObject(SysUtils)

- (BOOL)checkOtool: (NSString *)filePath
{
    NSString *otoolPath = [self otoolPath];
    NSTask* otoolTask = [[[NSTask alloc] init] autorelease];
    NSPipe* silence = [NSPipe pipe];

    [otoolTask setLaunchPath: otoolPath];
    [otoolTask setStandardInput: [NSPipe pipe]];
    [otoolTask setStandardOutput: silence];
    [otoolTask setStandardError: silence];
    [otoolTask launch];
    [otoolTask waitUntilExit];
    
    return ([otoolTask terminationStatus] == 1);
}

//  pathForTool:
// ----------------------------------------------------------------------------


- (NSString *)otoolPath {
    static NSString *otoolPath = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        otoolPath = [self pathForTool:@"otool"];
        NSAssert(otoolPath != nil, @"otool wasn't found");
    });
                  
    return otoolPath;
}
                  
- (NSString *)pathForTool:(NSString *)toolName
{
    NSString *path = nil;
    
    NSString *relToolBase = [NSString pathWithComponents:@[@"/", @"usr", @"bin"]];
    NSString *selectToolPath = [relToolBase stringByAppendingPathComponent: @"xcode-select"];
    NSTask *selectTask = [[[NSTask alloc] init] autorelease];
    NSPipe *selectPipe = [NSPipe pipe];
    NSArray *args = [NSArray arrayWithObject: @"--print-path"];
    
    [selectTask setLaunchPath: selectToolPath];
    [selectTask setArguments: args];
    [selectTask setStandardInput: [NSPipe pipe]];
    [selectTask setStandardOutput: selectPipe];
    [selectTask launch];
    [selectTask waitUntilExit];
    
    int selectStatus = [selectTask terminationStatus];
    
    if (selectStatus == -1) { return nil; }
    
    NSData* selectData = [[selectPipe fileHandleForReading] availableData];
    NSString* absToolPath = [[[NSString alloc] initWithBytes: [selectData bytes]
                                                      length: [selectData length]
                                                    encoding: NSUTF8StringEncoding] autorelease];
    
    
    NSString *xcodePath = [absToolPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    path = searchForFile(xcodePath, toolName);
    
    return path;
}

@end
