#ifndef LlamaCppBridge_h
#define LlamaCppBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// LlamaCpp context wrapper
@interface LLMContext : NSObject

/// Initialize with model path
- (nullable instancetype)initWithModelPath:(NSString *)path
                               contextSize:(NSInteger)contextSize
                                  nThreads:(NSInteger)nThreads;

/// Generate text from prompt
- (nullable NSString *)generateWithPrompt:(NSString *)prompt
                                maxTokens:(NSInteger)maxTokens
                              temperature:(float)temperature
                                     topP:(float)topP
                                     topK:(NSInteger)topK
                               repeatPenalty:(float)repeatPenalty;

/// Stream generation with callback
- (void)streamGenerateWithPrompt:(NSString *)prompt
                       maxTokens:(NSInteger)maxTokens
                     temperature:(float)temperature
                            topP:(float)topP
                            topK:(NSInteger)topK
                   repeatPenalty:(float)repeatPenalty
                        callback:(void (^)(NSString * _Nullable token, BOOL isComplete))callback;

/// Get model info
@property (nonatomic, readonly) NSString *modelName;
@property (nonatomic, readonly) NSInteger modelSize;
@property (nonatomic, readonly) NSInteger contextLength;

/// Memory management
- (void)clearContext;

@end

NS_ASSUME_NONNULL_END

#endif /* LlamaCppBridge_h */