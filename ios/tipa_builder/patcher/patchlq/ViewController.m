#import "ViewController.h"
#import "Patcher.h"

@interface ViewController ()
@property (nonatomic, strong) UIButton *patchKGVN;
@property (nonatomic, strong) UIButton *patchKGTW;
@property (nonatomic, strong) UIButton *patchKGTH;
@property (nonatomic, strong) UIButton *unpatchButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *bgImage;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)setupUI {
    self.title = @"Orthora Patch AOV";
    self.view.backgroundColor = [UIColor whiteColor];

    // Background image (funny.JPG bundled)
    _bgImage = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _bgImage.image = [UIImage imageNamed:@"funny"];
    _bgImage.contentMode = UIViewContentModeScaleAspectFill;
    _bgImage.alpha = 0.15;
    [self.view addSubview:_bgImage];

    CGFloat y = 120;
    CGFloat w = self.view.bounds.size.width - 60;

    // Title label
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, y, w, 30)];
    titleLabel.text = @"Select Game Version";
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor blackColor];
    [self.view addSubview:titleLabel];

    y += 50;

    // Region buttons
    _patchKGVN = [self buttonWithTitle:@"KGVN (Vietnam)" frame:CGRectMake(30, y, w, 50) tag:1];
    y += 60;
    _patchKGTW = [self buttonWithTitle:@"KGTW (Taiwan)" frame:CGRectMake(30, y, w, 50) tag:2];
    y += 60;
    _patchKGTH = [self buttonWithTitle:@"KGTH (Thailand)" frame:CGRectMake(30, y, w, 50) tag:3];

    y += 80;

    // Unpatch button
    _unpatchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _unpatchButton.frame = CGRectMake(30, y, w, 50);
    _unpatchButton.backgroundColor = [UIColor systemRedColor];
    [_unpatchButton setTitle:@"Unpatch Hack" forState:UIControlStateNormal];
    [_unpatchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _unpatchButton.layer.cornerRadius = 12;
    _unpatchButton.tag = 4;
    [_unpatchButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_unpatchButton];

    y += 70;

    // Status label
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, y, w, 60)];
    _statusLabel.text = @"Ready";
    _statusLabel.font = [UIFont systemFontOfSize:14];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 3;
    _statusLabel.textColor = [UIColor darkGrayColor];
    [self.view addSubview:_statusLabel];

    // Spinner
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.center = CGPointMake(self.view.center.x, y + 50);
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];
}

- (UIButton *)buttonWithTitle:(NSString *)title frame:(CGRect)frame tag:(NSInteger)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor = [UIColor systemBlueColor];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    btn.layer.cornerRadius = 12;
    btn.tag = tag;
    [btn addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}

- (void)buttonTapped:(UIButton *)sender {
    NSString *region = nil;
    BOOL isPatch = YES;

    switch (sender.tag) {
        case 1: region = @"kgvn"; break;
        case 2: region = @"kgtw"; break;
        case 3: region = @"kgth"; break;
        case 4: isPatch = NO; break;
    }

    if (isPatch && !region) return;

    [self setButtonsEnabled:NO];
    [_spinner startAnimating];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success;

        if (isPatch) {
            self.statusLabel.text = [NSString stringWithFormat:@"Patching %@...", region.uppercaseString];
            success = [Patcher patchGame:region error:&error];
        } else {
            self.statusLabel.text = @"Unpatching...";
            success = [Patcher unpatchGame:&error];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            [self setButtonsEnabled:YES];

            if (success) {
                self.statusLabel.text = isPatch ?
                    [NSString stringWithFormat:@"%@ patched! Restart the game.", region.uppercaseString] :
                    @"Unpatched successfully!";
                self.statusLabel.textColor = [UIColor systemGreenColor];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"Error: %@", error.localizedDescription ?: @"Unknown"];
                self.statusLabel.textColor = [UIColor systemRedColor];
            }
        });
    });
}

- (void)setButtonsEnabled:(BOOL)enabled {
    _patchKGVN.enabled = enabled;
    _patchKGTW.enabled = enabled;
    _patchKGTH.enabled = enabled;
    _unpatchButton.enabled = enabled;
}

@end
