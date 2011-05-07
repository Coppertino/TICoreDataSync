//
//  TICDSError.h
//  ShoppingListMac
//
//  Created by Tim Isted on 21/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICDSTypesAndEnums.h"

/** `TICDSError` is a utility class to generate `NSError` objects with certain characteristics.
 
 Any error generated by one of the calls to `TICDSError` will be an instance of `TICDSError`. The only difference between `NSError` and `TICDSError` is that it overrides the `description` method to show the entire contents of the error's `userInfo` dictionary. 
 
 `TICDSError` can optionally include a stack trace in every error object it generates. Call `[TICDSError setIncludeStackTraceInErrors:]` and pass `YES` before generating any errors to enable this option. Obviously, because of the way these are generated, the stack trace will include the methods used to generate the error.
 
 With `includesStackTraceInErrors` turned on, examining an error using `NSLog(@"%@", someError)` will display output similar to the following:
 
     Error Domain=com.timisted.ticoredatasync Code=2 UserInfo=0x10064f1a0 "File Manager error"
     User Info:{
     NSLocalizedDescription = "File Manager error";
     kTICDSErrorClassAndMethod = "-[TICDSFileManagerBasedVacuumOperation findOutLeastRecentClientSyncDate]";
     kTICDSErrorUnderlyingError = "Error Domain=NSCocoaErrorDomain Code=256 UserInfo=0x100649400 \"The file couldn\U2019t be opened.\" Underlying Error=(Error Domain=NSOSStatusErrorDomain Code=-2111 \"The operation couldn\U2019t be completed. (OSStatus error -2111.)\")";
     kTICDSStackTrace =     (
     "0   ShoppingListMac                     0x000000010000b08e +[TICDSError errorWithCode:underlyingError:userInfo:classAndMethod:] + 590",
     "1   ShoppingListMac                     0x000000010000ae38 +[TICDSError errorWithCode:underlyingError:classAndMethod:] + 72",
     "2   ShoppingListMac                     0x000000010003ae46 -[TICDSFileManagerBasedVacuumOperation findOutLeastRecentClientSyncDate] + 310",
     "3   ShoppingListMac                     0x000000010003a203 -[TICDSVacuumOperation beginFindingOutLeastRecentClientSyncDate] + 211",
     "4   ShoppingListMac                     0x000000010003a126 -[TICDSVacuumOperation main] + 54",
     "5   ShoppingListMac                     0x000000010000b410 -[TICDSOperation start] + 368",
     "6   Foundation                          0x00007fff80138ae7 __doStart2 + 97",
     "7   libSystem.B.dylib                   0x00007fff84fdb284 _dispatch_call_block_and_release + 15",
     "8   libSystem.B.dylib                   0x00007fff84fb97f1 _dispatch_worker_thread2 + 239",
     "9   libSystem.B.dylib                   0x00007fff84fb9128 _pthread_wqthread + 353",
     "10  libSystem.B.dylib                   0x00007fff84fb8fc5 start_wqthread + 13"
     );
     }
 
 */

@interface TICDSError : NSError {
@private
}

/** @name Error Generation */

/** Generate an error with the given code.
 
 @param aCode The error code to use.
 @param someInfo The user info to set on the `NSError` object.
 
 @return A properly-configured `NSError` object.
 */
+ (NSError *)errorWithCode:(TICDSErrorCode)aCode userInfo:(id)someInfo;

/** Generate an error with the given code in a specific class and method.
 
 @param aCode The error code to use.
 @param aClassAndMethod A C-string, typically provided by `__PRETTY_FUNCTION__`.
 
 @return A properly-configured `NSError` object with the class and method specified in the user info.
 */
+ (NSError *)errorWithCode:(TICDSErrorCode)aCode classAndMethod:(const char *)aClassAndMethod;

/** Generate an error with the given code and another *underlying error* in a specific class and method.
 
 @param aCode The error code to use.
 @param anUnderlyingError The underlying `NSError` that caused this particular `TICoreDataSync` error.
 @param aClassAndMethod A C-string, typically provided by `__PRETTY_FUNCTION__`.
 
 @return A properly-configured `NSError` object, with the underlying error, and class and method specified in the user info.
 */
+ (NSError *)errorWithCode:(TICDSErrorCode)aCode underlyingError:(NSError *)anUnderlyingError classAndMethod:(const char *)aClassAndMethod;

/** Generate an error with the given code and another *underlying error* in a specific class and method, also providing your own user info.
 
 @param aCode The error code to use.
 @param anUnderlyingError The underlying `NSError` that caused this particular `TICoreDataSync` error.
 @param someInfo The user info you wish to supply (in addition that created automatically) for this error.
 @param aClassAndMethod A C-string, typically provided by `__PRETTY_FUNCTION__`.
 
 @return A properly-configured `NSError` object, with the underlying error and class and method, specified in the user info, which will be merged with the provided `someInfo`.
 */
+ (NSError *)errorWithCode:(TICDSErrorCode)aCode underlyingError:(NSError *)anUnderlyingError userInfo:(id)someInfo classAndMethod:(const char *)aClassAndMethod;

/** @name Error Stack Trace Logging */

/** Specify whether to include a stack trace in errors generated by `TICDSError` class factory methods.
 
 @param shouldInclude A Boolean indicating whether to include a stack trace. */
+ (void)setIncludeStackTraceInErrors:(BOOL)shouldInclude;

/** Indicates whether a stack trace will be included in  errors generated by `TICDSError` class factory methods.
 
 @return A Boolean indicating whether a stack trace will be included. */
+ (BOOL)includeStackTraceInErrors;

@end
