//
//  UIHelper.m
//  Ares2ToolBox
//

#import "UIHelper.h"

@implementation UIHelper

+ (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
            viewController:(UIViewController *)vc {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}

+ (void)showConfirmWithTitle:(NSString *)title
                     message:(NSString *)message
              viewController:(UIViewController *)vc
                  completion:(void (^)(BOOL))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (completion) completion(NO);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completion) completion(YES);
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

+ (void)showInputDialogWithTitle:(NSString *)title
                         message:(NSString *)message
                  viewController:(UIViewController *)vc
                      completion:(void (^)(NSString * _Nullable))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (completion) completion(nil);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = alert.textFields.firstObject.text;
        if (completion) completion(text);
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

+ (UIButton *)createRoundedButtonWithTitle:(NSString *)title
                                     color:(UIColor *)color
                                    target:(id)target
                                    action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.backgroundColor = color;
    button.layer.cornerRadius = 8;
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

+ (UILabel *)createLabelWithText:(NSString *)text
                            font:(UIFont *)font
                           color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

@end