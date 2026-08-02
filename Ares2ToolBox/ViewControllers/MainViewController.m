//
//  MainViewController.m
//  Ares2ToolBox
//
//  主界面实现 - 提供存档导入、解密、数据库浏览编辑功能
//

#import "MainViewController.h"
#import "FileProcessor.h"
#import "DatabaseManager.h"
#import "Constants.h"
#import "UIHelper.h"
#import "Models.h"
#import "AssetLoaderUtil.h"

@interface MainViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

@property (nonatomic, strong) FileProcessor *fileProcessor;
@property (nonatomic, strong) DatabaseManager *dbManager;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *viewSegment;

// 数据
@property (nonatomic, strong) NSArray<TreeNode *> *treeNodes;
@property (nonatomic, strong) NSArray<NSDictionary *> *currentTableData;
@property (nonatomic, strong) NSArray<NSString *> *currentColumns;

// 搜索
@property (nonatomic, strong) UISearchController *searchController;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Ares2工具箱";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.fileProcessor = [[FileProcessor alloc] init];
    self.dbManager = [[DatabaseManager alloc] init];

    [self setupUI];
    [self setupNavigationBar];
    [self ensureSaveDirectory];
}

- (void)ensureSaveDirectory {
    NSString *dir = [Constants saveDirectory];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
}

#pragma mark - UI Setup

- (void)setupNavigationBar {
    UIBarButtonItem *importBtn = [[UIBarButtonItem alloc] initWithTitle:@"导入存档"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(importArchive)];
    UIBarButtonItem *exportBtn = [[UIBarButtonItem alloc] initWithTitle:@"导出"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(exportArchive)];
    self.navigationItem.rightBarButtonItems = @[exportBtn, importBtn];

    // 搜索
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchBar.placeholder = @"搜索表数据...";
    self.searchController.searchBar.delegate = (id)self;
    self.navigationItem.searchController = self.searchController;
}

- (void)setupUI {
    CGFloat padding = 16;
    CGFloat y = 100;

    // 状态标签
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, self.view.bounds.size.width - 2*padding, 24)];
    self.statusLabel.text = @"请导入存档文件开始编辑";
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    y += 30;

    // 进度条
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(padding, y, self.view.bounds.size.width - 2*padding, 4)];
    self.progressView.progress = 0;
    self.progressView.hidden = YES;
    [self.view addSubview:self.progressView];
    y += 10;

    // 进度标签
    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, self.view.bounds.size.width - 2*padding, 20)];
    self.progressLabel.font = [UIFont systemFontOfSize:12];
    self.progressLabel.textColor = [UIColor secondaryLabelColor];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.hidden = YES;
    [self.view addSubview:self.progressLabel];
    y += 30;

    // 分段控件
    self.viewSegment = [[UISegmentedControl alloc] initWithItems:@[@"数据库表格", @"文件浏览"]];
    self.viewSegment.frame = CGRectMake(padding, y, self.view.bounds.size.width - 2*padding, 32);
    self.viewSegment.selectedSegmentIndex = 0;
    [self.viewSegment addTarget:self action:@selector(viewSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.viewSegment];
    y += 44;

    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, self.view.bounds.size.height - y - 100)
                                                   style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.view addSubview:self.tableView];
}

#pragma mark - Actions

- (void)importArchive {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithFilenameExtension:@"zip"] ?: UTTypeArchive]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)exportArchive {
    if (!self.fileProcessor.decryptedDbPath) {
        [UIHelper showAlertWithTitle:@"提示" message:@"请先导入并处理存档" viewController:self];
        return;
    }

    self.progressView.hidden = NO;
    self.progressLabel.hidden = NO;

    [self.fileProcessor finishExportWithTempDir:self.fileProcessor.tempDirPath
                                     outputPath:[[Constants saveDirectory] stringByAppendingPathComponent:
                                                 [NSString stringWithFormat:@"exported_%lld.zip", (long long)([[NSDate date] timeIntervalSince1970] * 1000)]]
                                       progress:^(NSInteger progress, NSString *message) {
        self.progressView.progress = progress / 100.0;
        self.progressLabel.text = message;
    } completion:^(BOOL success, NSString * _Nullable resultPath, NSString * _Nullable errorMessage) {
        self.progressView.hidden = YES;
        self.progressLabel.hidden = YES;
        if (success) {
            [UIHelper showAlertWithTitle:@"成功" message:[NSString stringWithFormat:@"导出到: %@", resultPath] viewController:self];
        } else {
            [UIHelper showAlertWithTitle:@"失败" message:errorMessage viewController:self];
        }
    }];
}

- (void)viewSegmentChanged:(UISegmentedControl *)sender {
    [self.tableView reloadData];
}

- (void)processArchiveAtURL:(NSURL *)url {
    self.progressView.hidden = NO;
    self.progressLabel.hidden = NO;
    self.statusLabel.text = @"正在处理存档...";

    NSString *inputPath = url.path;
    [self.fileProcessor processFile:inputPath
                          outputDir:[Constants saveDirectory]
                           progress:^(NSInteger progress, NSString *message) {
        self.progressView.progress = progress / 100.0;
        self.progressLabel.text = message;
    } completion:^(BOOL success, NSString * _Nullable resultPath, NSString * _Nullable errorMessage) {
        self.progressView.hidden = YES;
        self.progressLabel.hidden = YES;

        if (success) {
            self.statusLabel.text = @"存档已就绪，可以浏览和编辑";
            [self.dbManager openDatabase:resultPath];
            [self.dbManager loadAllTableNames];
            [self buildTreeNodes];
            [self.tableView reloadData];
        } else {
            self.statusLabel.text = @"处理失败";
            [UIHelper showAlertWithTitle:@"错误" message:errorMessage viewController:self];
        }
    }];
}

- (void)buildTreeNodes {
    NSMutableArray *nodes = [NSMutableArray array];
    for (NSString *tableName in self.dbManager.tableNames) {
        TreeNode *node = [[TreeNode alloc] init];
        node.name = tableName;
        node.type = 3; // table
        [nodes addObject:node];
    }
    self.treeNodes = [nodes copy];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (url) {
        [self processArchiveAtURL:url];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.viewSegment.selectedSegmentIndex == 0) {
        return self.currentTableData ? self.currentTableData.count : self.treeNodes.count;
    }
    return self.treeNodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    if (self.viewSegment.selectedSegmentIndex == 0) {
        if (self.currentTableData) {
            // 显示表数据行
            NSDictionary *row = self.currentTableData[indexPath.row];
            NSString *display = [NSString stringWithFormat:@"行%ld: ", (long)(indexPath.row + 1)];
            for (NSString *col in self.currentColumns) {
                if ([col isEqualToString:@"_id"]) continue;
                NSString *val = row[col] ?: @"";
                display = [display stringByAppendingFormat:@"%@=%@ ", col, val];
            }
            cell.textLabel.text = display;
            cell.textLabel.font = [UIFont systemFontOfSize:11];
            cell.textLabel.numberOfLines = 2;
        } else {
            // 显示表列表
            TreeNode *node = self.treeNodes[indexPath.row];
            cell.textLabel.text = node.name;
            cell.textLabel.font = [UIFont systemFontOfSize:14];
            cell.textLabel.numberOfLines = 1;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        TreeNode *node = self.treeNodes[indexPath.row];
        cell.textLabel.text = node.name;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.viewSegment.selectedSegmentIndex == 0 && !self.currentTableData) {
        // 选中了一个表，加载数据
        TreeNode *node = self.treeNodes[indexPath.row];
        [self.dbManager loadTableColumnInfo:node.name];
        self.currentTableData = [self.dbManager loadTableData:node.name];
        self.currentColumns = self.dbManager.tableColumns[node.name];
        self.title = [NSString stringWithFormat:@"表: %@", node.name];
        [self.tableView reloadData];

        // 添加返回按钮
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(backToTableList)];
    } else if (self.currentTableData) {
        // 编辑单元格
        [self editCellAtIndexPath:indexPath];
    }
}

- (void)backToTableList {
    self.currentTableData = nil;
    self.currentColumns = nil;
    self.title = @"Ares2工具箱";
    self.navigationItem.leftBarButtonItem = nil;
    [self.tableView reloadData];
}

- (void)editCellAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.currentTableData[indexPath.row];
    NSString *rowId = row[@"_id"];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"编辑行"
                                                                   message:[NSString stringWithFormat:@"RowID: %@", rowId]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *col in self.currentColumns) {
        if ([col isEqualToString:@"_id"]) continue;
        NSString *currentVal = row[col] ?: @"";
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@: %@", col, currentVal]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self showEditDialogForColumn:col rowId:rowId currentValue:currentVal];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showEditDialogForColumn:(NSString *)column rowId:(NSString *)rowId currentValue:(NSString *)currentValue {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"编辑 %@", column]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = currentValue;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newValue = alert.textFields.firstObject.text;
        BOOL success = [self.dbManager updateCellInTable:self.dbManager.currentTable
                                                   rowId:[rowId integerValue]
                                              columnName:column
                                                   value:newValue];
        if (success) {
            self.currentTableData = [self.dbManager loadTableData:self.dbManager.currentTable];
            [self.tableView reloadData];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *keyword = searchBar.text;
    if (keyword.length == 0) return;

    [self.dbManager searchAllTables:keyword
                           progress:^(NSString *tableName, NSInteger foundCount) {
        self.statusLabel.text = [NSString stringWithFormat:@"搜索中: %@ (已找到%ld条)", tableName, (long)foundCount];
    } completion:^(NSArray<NSDictionary *> *results) {
        self.statusLabel.text = [NSString stringWithFormat:@"搜索完成，找到%lu条结果", (unsigned long)results.count];
        [self.searchController setActive:NO];

        if (results.count > 0) {
            NSMutableString *msg = [NSMutableString string];
            for (DBSearchResult *r in results) {
                [msg appendFormat:@"[%@] %@ = %@\n", r.tableName, r.columnName, r.matchedText];
            }
            [UIHelper showAlertWithTitle:@"搜索结果" message:msg viewController:self];
        }
    }];
}

@end