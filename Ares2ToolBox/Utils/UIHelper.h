//
//  UIHelper.h
//  Ares2ToolBox
//
//  UI工具类
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIHelper : NSObject

/// 显示警告框
+ (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
            viewController:(UIViewController *)vc;

/// 显示确认对话框
+ (void)showConfirmWithTitle:(NSString *)title
                     message:(NSString *)message
              viewController:(UIViewController *)vc
                  completion:(void (^)(BOOL confirmed))completion;

/// 显示输入对话框
+ (void)showInputDialogWithTitle:(NSString *)title
                         message:(NSString *)message
                  viewController:(UIViewController *)vc
                      completion:(void (^)(NSString * _Nullable text))completion;

/// 创建圆角按钮
+ (UIButton *)createRoundedButtonWithTitle:(NSString *)title
                                     color:(UIColor *)color
                                    target:(id)target
                                    action:(SEL)action;

/// 创建标签
+ (UILabel *)createLabelWithText:(NSString *)text
                            font:(UIFont *)font
                           color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END