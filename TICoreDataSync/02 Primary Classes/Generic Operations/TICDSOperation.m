//
//  TICDSOperation.m
//  ShoppingListMac
//
//  Created by Tim Isted on 21/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"


@implementation TICDSOperation

#pragma mark - Primary Operation
- (void)start
{
    if( [self needsMainThread] && ![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    } else if( ![self needsMainThread] && [NSThread isMainThread] ) {
        [self performSelectorInBackground:@selector(start) withObject:nil];
        return;
    }
    
    // Configure the Cryptor object, if encryption is enabled
    if( [self shouldUseEncryption] ) {
        FZACryptor *aCryptor = [[FZACryptor alloc] init];
        [self setCryptor:aCryptor];
    }

    [self operationDidStart];
    
    if( [self isCancelled] ) {
        [self operationWasCancelled];
        return;
    }
    
    [self main];
}

- (void)main
{
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeMethodNotOverriddenBySubclass classAndMethod:__PRETTY_FUNCTION__]];
    
    [self operationDidFailToComplete];
}

#pragma mark - Operation Settings
- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)needsMainThread
{
    return NO;
}

#pragma mark - Completion
- (void)endExecution
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)ticdPrivate_operationDidCompleteSuccessfully:(BOOL)success cancelled:(BOOL)wasCancelled
{
    // cleanup temporary directory, if necessary
    if( _tempFileDirectoryPath ) {
        [[self fileManager] removeItemAtPath:_tempFileDirectoryPath error:nil];
    }
    
    if( success ) {
        TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation completed successfully");
        if ([self ti_delegateRespondsToSelector:@selector(operationCompletedSuccessfully:)]) {
            [self runOnMainQueueWithoutDeadlocking:^{
                [(id)self.delegate operationCompletedSuccessfully:self];
            }];
        }
    } else if( wasCancelled ) {
        TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation was cancelled");
        if ([self ti_delegateRespondsToSelector:@selector(operationWasCancelled:)]) {
            [self runOnMainQueueWithoutDeadlocking:^{
                [(id)self.delegate operationWasCancelled:self];
            }];
        }
    } else {
        TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation failed to complete");
        if ([self ti_delegateRespondsToSelector:@selector(operationFailedToComplete:)]) {
            [self runOnMainQueueWithoutDeadlocking:^{
                [(id)self.delegate operationFailedToComplete:self];
            }];
        }
    }
    
    // This is a nasty way to, I think, avoid a problem with the DropboxSDK on iOS - must revisit and sort out soon
    if( [NSThread isMainThread] ) {
        [self performSelector:@selector(endExecution) withObject:nil afterDelay:0.1];
    } else {
        [self endExecution];
    }
}

- (void)operationDidStart
{
    TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation started");
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)operationDidCompleteSuccessfully
{
    [self ticdPrivate_operationDidCompleteSuccessfully:YES cancelled:NO];
}

- (void)operationDidFailToComplete
{
    [self ticdPrivate_operationDidCompleteSuccessfully:NO cancelled:NO];
}

- (void)operationWasCancelled
{
    [self ticdPrivate_operationDidCompleteSuccessfully:NO cancelled:YES];
}

#pragma mark - Lazy Accessors
- (NSFileManager *)fileManager
{
    if( _fileManager ) return _fileManager;
    
    _fileManager = [[NSFileManager alloc] init];
    
    return _fileManager;
}

#pragma mark - Initialization and Deallocation
- (id)initWithDelegate:(NSObject <TICDSOperationDelegate> *)aDelegate
{
    self = [super init];
    if( !self ) return nil;
    
    _delegate = aDelegate;
    
    _isExecuting = NO;
    _isFinished = NO;
    
    return self;
}

- (void)dealloc
{
    _cryptor = nil;
    _userInfo = nil;
    _error = nil;
    _clientIdentifier = nil;
    _fileManager = nil;
    _tempFileDirectoryPath = nil;

}

#pragma mark - Lazy Accessors
- (NSString *)tempFileDirectoryPath
{
    if( _tempFileDirectoryPath ) {
        return _tempFileDirectoryPath;
    }
    
    NSString *aDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[TICDSUtilities uuidString]];
    
    NSError *anyError = nil;
    BOOL success = [[self fileManager] createDirectoryAtPath:aDirectoryPath withIntermediateDirectories:NO attributes:nil error:&anyError];
    
    if( !success ) {
        TICDSLog(TICDSLogVerbosityErrorsOnly, @"Internal error: unable to create temp file directory");
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    _tempFileDirectoryPath = aDirectoryPath;
    
    return _tempFileDirectoryPath;
}

#pragma mark - Properties
@synthesize shouldUseEncryption = _shouldUseEncryption;
@synthesize cryptor = _cryptor;
@synthesize delegate = _delegate;
@synthesize userInfo = _userInfo;
@synthesize isExecuting = _isExecuting;
@synthesize isFinished = _isFinished;
@synthesize error = _error;
@synthesize fileManager = _fileManager;
@synthesize tempFileDirectoryPath = _tempFileDirectoryPath;
@synthesize clientIdentifier = _clientIdentifier;

@end
