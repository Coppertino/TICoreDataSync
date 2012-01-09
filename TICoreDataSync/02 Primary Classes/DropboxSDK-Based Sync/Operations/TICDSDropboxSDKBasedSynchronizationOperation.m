//
//  TICDSDropboxSDKBasedSynchronizationOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"

@interface TICDSDropboxSDKBasedSynchronizationOperation ()

/** A dictionary used by this operation to find out the client responsible for creating a change set. */
@property (nonatomic, retain) NSMutableDictionary *clientIdentifiersForChangeSetIdentifiers;

/** A dictionary used to keep hold of the modification dates of sync change sets. */
@property (nonatomic, retain) NSMutableDictionary *changeSetModificationDates;

/** When we fail to download a changeset file we re-request it and put its path in this set so that we can keep track of the fact that we've re-requested it. */
@property (nonatomic, copy) NSMutableDictionary *failedDownloadRetryDictionary;

@end

@implementation TICDSDropboxSDKBasedSynchronizationOperation

#pragma mark -
#pragma mark Overridden Methods
- (BOOL)needsMainThread
{
    return YES;
}

#pragma mark Integrity Key
- (void)fetchRemoteIntegrityKey
{
    NSString *directoryPath = [[self thisDocumentDirectoryPath] stringByAppendingPathComponent:TICDSIntegrityKeyDirectoryName];
    
    [[self restClient] loadMetadata:directoryPath];
}

#pragma mark Sync Change Sets
- (void)buildArrayOfClientDeviceIdentifiers
{
    [[self restClient] loadMetadata:[self thisDocumentSyncChangesDirectoryPath]];
}

- (void)buildArrayOfSyncChangeSetIdentifiersForClientIdentifier:(NSString *)anIdentifier
{
    [[self restClient] loadMetadata:[self pathToSyncChangesDirectoryForClientWithIdentifier:anIdentifier]];
}

- (void)fetchSyncChangeSetWithIdentifier:(NSString *)aChangeSetIdentifier forClientIdentifier:(NSString *)aClientIdentifier toLocation:(NSURL *)aLocation
{
    if( ![self clientIdentifiersForChangeSetIdentifiers] ) {
        [self setClientIdentifiersForChangeSetIdentifiers:[NSMutableDictionary dictionaryWithCapacity:10]];
    }
    
    [[self clientIdentifiersForChangeSetIdentifiers] setValue:aClientIdentifier forKey:aChangeSetIdentifier];
    
    [[self restClient] loadFile:[self pathToSyncChangeSetWithIdentifier:aChangeSetIdentifier forClientWithIdentifier:aClientIdentifier] intoPath:[aLocation path]];
}

#pragma mark Uploading Change Sets
- (void)uploadLocalSyncChangeSetFileAtLocation:(NSURL *)aLocation
{
    NSString *finalFilePath = [aLocation path];
    
    if( [self shouldUseEncryption] ) {
        NSString *tempFilePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:[finalFilePath lastPathComponent]];
        
        NSError *anyError = nil;
        BOOL success = [[self cryptor] encryptFileAtLocation:aLocation writingToLocation:[NSURL fileURLWithPath:tempFilePath] error:&anyError];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            [self uploadedLocalSyncChangeSetFileSuccessfully:NO];
            return;
        }
        
        finalFilePath = tempFilePath;
    }
    
    [[self restClient] uploadFile:[finalFilePath lastPathComponent] toPath:[self thisDocumentSyncChangesThisClientDirectoryPath] withParentRev:nil fromPath:finalFilePath];
//    [[self restClient] uploadFile:[finalFilePath lastPathComponent] toPath:[self thisDocumentSyncChangesThisClientDirectoryPath] fromPath:finalFilePath];
}

#pragma mark Uploading Recent Sync File
- (void)uploadRecentSyncFileAtLocation:(NSURL *)aLocation
{
    [[self restClient] uploadFile:[[aLocation path] lastPathComponent] toPath:[[self thisDocumentRecentSyncsThisClientFilePath] stringByDeletingLastPathComponent] withParentRev:nil fromPath:[aLocation path]];
//    [[self restClient] uploadFile:[[aLocation path] lastPathComponent] toPath:[[self thisDocumentRecentSyncsThisClientFilePath] stringByDeletingLastPathComponent] fromPath:[aLocation path]];
}

#pragma mark -
#pragma mark Rest Client Delegate
#pragma mark Metadata
- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    NSString *path = [metadata path];
    
    if( [path isEqualToString:[self thisDocumentSyncChangesDirectoryPath]] ) {
        NSMutableArray *clientDeviceIdentifiers = [NSMutableArray arrayWithCapacity:[[metadata contents] count]];
        NSString *identifier = nil;
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            identifier = [[eachSubMetadata path] lastPathComponent];
            
            if( [identifier length] < 5 || [eachSubMetadata isDeleted] ) {
                continue;
            }
            
            [clientDeviceIdentifiers addObject:identifier];
        }
        
        [self builtArrayOfClientDeviceIdentifiers:clientDeviceIdentifiers];
        return;
    }
    
    if( [[path stringByDeletingLastPathComponent] isEqualToString:[self thisDocumentSyncChangesDirectoryPath]] ) {
        if( ![self changeSetModificationDates] ) {
            [self setChangeSetModificationDates:[NSMutableDictionary dictionaryWithCapacity:20]];
        }
        
        NSMutableArray *syncChangeSetIdentifiers = [NSMutableArray arrayWithCapacity:[[metadata contents] count]];
        NSString *identifier = nil;
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            identifier = [[[eachSubMetadata path] lastPathComponent] stringByDeletingPathExtension];
            
            if( [identifier length] < 5 || [eachSubMetadata isDeleted] ) {
                continue;
            }
            
            [syncChangeSetIdentifiers addObject:identifier];
            [[self changeSetModificationDates] setValue:[eachSubMetadata lastModifiedDate] forKey:identifier];
        }
        
        [self builtArrayOfClientSyncChangeSetIdentifiers:syncChangeSetIdentifiers forClientIdentifier:[path lastPathComponent]];
    }
    
    if( [[path lastPathComponent] isEqualToString:TICDSIntegrityKeyDirectoryName] ) {
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            if( [[[eachSubMetadata path] lastPathComponent] length] < 5 ) {
                continue;
            }
            
            [self fetchedRemoteIntegrityKey:[[eachSubMetadata path] lastPathComponent]];
            return;
        }
        
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeSynchronizationFailedBecauseIntegrityKeyDirectoryIsMissing classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
        return;
    }
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path
{
    
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];

    if( [path isEqualToString:[self thisDocumentSyncChangesDirectoryPath]] ) {
        [self builtArrayOfClientDeviceIdentifiers:nil];
        return;
    }
    
    if( [[path stringByDeletingLastPathComponent] isEqualToString:[self thisDocumentSyncChangesDirectoryPath]] ) {
        [self builtArrayOfClientSyncChangeSetIdentifiers:nil forClientIdentifier:[path lastPathComponent]];
        return;
    }
    
    if( [[path lastPathComponent] isEqualToString:TICDSIntegrityKeyDirectoryName] ) {
        if( [error code] == 404 ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeSynchronizationFailedBecauseIntegrityKeyDirectoryIsMissing underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
        } else {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
        }
        [self fetchedRemoteIntegrityKey:nil];
        return;
    }
}

#pragma mark Loading Files
- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath
{
    NSError *anyError = nil;
    BOOL success = YES;
    
    if( [[[destPath lastPathComponent] pathExtension] isEqualToString:TICDSSyncChangeSetFileExtension] ) {
        
        NSString *changeSetIdentifier = [[destPath lastPathComponent] stringByDeletingPathExtension];
        NSString *clientIdentifier = [[self clientIdentifiersForChangeSetIdentifiers] valueForKey:changeSetIdentifier];
        
        if( [self shouldUseEncryption] ) {
            NSString *tmpPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:[destPath lastPathComponent]];
            
            success = [[self fileManager] moveItemAtPath:destPath toPath:tmpPath error:&anyError];
            
            if( !success ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
                [self fetchedSyncChangeSetWithIdentifier:changeSetIdentifier forClientIdentifier:clientIdentifier modificationDate:nil withSuccess:NO];
                return;
            }
            
            success = [[self cryptor] decryptFileAtLocation:[NSURL fileURLWithPath:tmpPath] writingToLocation:[NSURL fileURLWithPath:destPath] error:&anyError];
            
            if( !success ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            }
        }
        
        [self fetchedSyncChangeSetWithIdentifier:changeSetIdentifier forClientIdentifier:clientIdentifier modificationDate:[[self changeSetModificationDates] valueForKey:changeSetIdentifier] withSuccess:success];
        return;
    }
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    NSString *downloadDestination = [[error userInfo] valueForKey:@"destinationPath"];
    
    if (path != nil && downloadDestination != nil && [[self.failedDownloadRetryDictionary objectForKey:path] integerValue] < 5) {
        NSInteger retryCount = [[self.failedDownloadRetryDictionary objectForKey:path] integerValue];
        retryCount++;
        TICDSLog(TICDSLogVerbosityErrorsOnly, @"Failed to download %@. Going for try number %d", path, retryCount);
        [self.failedDownloadRetryDictionary setObject:[NSNumber numberWithInteger:retryCount] forKey:path];
        [[self restClient] loadFile:path intoPath:downloadDestination];
        return;
    }
    
    if (path != nil) {
        [self.failedDownloadRetryDictionary setNilValueForKey:path];
    }
    
    TICDSLog(TICDSLogVerbosityErrorsOnly, @"Download of %@ has failed after 5 attempts, we're falling through to the error condition.", path);
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
    
    if( [[[path lastPathComponent] pathExtension] isEqualToString:TICDSSyncChangeSetFileExtension] ) {
        NSString *changeSetIdentifier = [[path lastPathComponent] stringByDeletingPathExtension];
        NSString *clientIdentifier = [[self clientIdentifiersForChangeSetIdentifiers] valueForKey:changeSetIdentifier];
        
        [self fetchedSyncChangeSetWithIdentifier:changeSetIdentifier forClientIdentifier:clientIdentifier modificationDate:nil withSuccess:NO];
        return;
    }
}

#pragma mark Uploads
- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath
{
    if( [[[destPath lastPathComponent] pathExtension] isEqualToString:TICDSSyncChangeSetFileExtension] ) {
        [self uploadedLocalSyncChangeSetFileSuccessfully:YES];
        return;
    }
    
    if( [destPath isEqualToString:[self thisDocumentRecentSyncsThisClientFilePath]] ) {
        [self uploadedRecentSyncFileSuccessfully:YES];
        return;
    }
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
    
    if( [[[path lastPathComponent] pathExtension] isEqualToString:TICDSSyncChangeSetFileExtension] ) {
        [self uploadedLocalSyncChangeSetFileSuccessfully:NO];
        return;
    }
    
    if( [path isEqualToString:[self thisDocumentRecentSyncsThisClientFilePath]] ) {
        [self uploadedRecentSyncFileSuccessfully:NO];
        return;
    }
}

#pragma mark -
#pragma mark Paths
- (NSString *)pathToSyncChangesDirectoryForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[self thisDocumentSyncChangesDirectoryPath] stringByAppendingPathComponent:anIdentifier];
}

- (NSString *)pathToSyncChangeSetWithIdentifier:(NSString *)aChangeSetIdentifier forClientWithIdentifier:(NSString *)aClientIdentifier
{
    return [[[self pathToSyncChangesDirectoryForClientWithIdentifier:aClientIdentifier] stringByAppendingPathComponent:aChangeSetIdentifier] stringByAppendingPathExtension:TICDSSyncChangeSetFileExtension];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    [_dbSession release], _dbSession = nil;
    [_restClient release], _restClient = nil;
    [_clientIdentifiersForChangeSetIdentifiers release], _clientIdentifiersForChangeSetIdentifiers = nil;
    [_changeSetModificationDates release], _changeSetModificationDates = nil;
    [_thisDocumentDirectoryPath release], _thisDocumentDirectoryPath = nil;
    [_thisDocumentSyncChangesDirectoryPath release], _thisDocumentSyncChangesDirectoryPath = nil;
    [_thisDocumentSyncChangesThisClientDirectoryPath release], _thisDocumentSyncChangesThisClientDirectoryPath = nil;
    [_thisDocumentRecentSyncsThisClientFilePath release], _thisDocumentRecentSyncsThisClientFilePath = nil;

    [super dealloc];
}

#pragma mark -
#pragma mark Lazy Accessors
- (DBRestClient *)restClient
{
    if( _restClient ) return _restClient;
    
    _restClient = [[DBRestClient alloc] initWithSession:[self dbSession]];
    [_restClient setDelegate:self];
    
    return _restClient;
}

- (NSMutableDictionary *)failedDownloadRetryDictionary
{
    if (_failedDownloadRetryDictionary == nil) {
        _failedDownloadRetryDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _failedDownloadRetryDictionary;
}

#pragma mark -
#pragma mark Properties
@synthesize dbSession = _dbSession;
@synthesize restClient = _restClient;
@synthesize clientIdentifiersForChangeSetIdentifiers = _clientIdentifiersForChangeSetIdentifiers;
@synthesize changeSetModificationDates = _changeSetModificationDates;
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentSyncChangesDirectoryPath = _thisDocumentSyncChangesDirectoryPath;
@synthesize thisDocumentSyncChangesThisClientDirectoryPath = _thisDocumentSyncChangesThisClientDirectoryPath;
@synthesize thisDocumentRecentSyncsThisClientFilePath = _thisDocumentRecentSyncsThisClientFilePath;
@synthesize failedDownloadRetryDictionary = _failedDownloadRetryDictionary;

@end

#endif