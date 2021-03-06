//
//  QuickPhotoViewController.m
//  WordPress
//
//  Created by Jorge Bernal on 4/6/11.
//  Copyright 2011 WordPress. All rights reserved.
//

#import <MobileCoreServices/UTCoreTypes.h>
#import "QuickPhotoViewController.h"
#import "WordPressAppDelegate.h"
#import "Blog.h"
#import "Media.h"
#import "CameraPlusPickerManager.h"
#import "WPPopoverBackgroundView.h"
#import "MP6SidebarViewController.h"
#import "IOS7CorrectedTextView.h"

@interface QuickPhotoViewController () {
    UIPopoverController *popController;
    BOOL showPickerAfterRotation;
}

@property (nonatomic, strong) UIPopoverController *popController;
@property (nonatomic, weak) IBOutlet UILabel *tapToBeginWritingLabel;

- (void)showPicker;
- (void)handleKeyboardWillShow:(NSNotification *)notification;
- (void)handleKeyboardWillHide:(NSNotification *)notification;

@end

@implementation QuickPhotoViewController

@synthesize photoImageView;
@synthesize titleTextField;
@synthesize contentTextView;
@synthesize blogSelector;
@synthesize postButtonItem;
@synthesize photo;
@synthesize sourceType;
@synthesize isCameraPlus;
@synthesize sidebarViewController;
@synthesize startingBlog;
@synthesize popController;


- (void)dealloc {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    self.photoImageView.delegate = nil;
    self.popController.delegate = nil;
}

- (void)didReceiveMemoryWarning {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewDidLoad];
        
    appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.titleTextField.placeholder = NSLocalizedString(@"Title (optional)", @"Quick Photo title");
    self.tapToBeginWritingLabel.text = NSLocalizedString(@"Tap here to begin writing", @"");
    self.contentTextView.delegate = self;
    
    [self.blogSelector loadBlogsForType:BlogSelectorButtonTypeQuickPhoto];
    self.blogSelector.delegate = self;
    if (self.startingBlog != nil) {
        self.blogSelector.activeBlog = startingBlog;
    }
    
    if (self.photo) {
        self.photoImageView.image = self.photo;
        [self saveImage];
    }
    self.photoImageView.delegate = self;
    self.title = NSLocalizedString(@"Quick Photo", @"");

    self.postButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Publish", @"")
                                                           style:[WPStyleGuide barButtonStyleForDone]
                                                          target:self
                                                          action:@selector(post)];

    [postButtonItem setEnabled:NO];
    self.navigationItem.rightBarButtonItem = self.postButtonItem;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [WPMobileStats trackEventForWPCom:StatsEventQuickPhotoOpened];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    startingFrame = self.view.frame;
    if (self.photo == nil) {
        [self showPicker];
    } else {
        self.photoImageView.image = self.photo;
    }
}

- (void)viewDidUnload {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.photoImageView.delegate = nil;
    self.photoImageView = nil;
    self.titleTextField = nil;
    self.contentTextView = nil;
    self.postButtonItem = nil;
    self.blogSelector.delegate = nil;
    self.blogSelector = nil;

    self.popController.delegate = nil;
    self.popController = nil;
}

- (NSUInteger)supportedInterfaceOrientations {
    if (IS_IPHONE) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (IS_IPAD || interfaceOrientation == UIDeviceOrientationPortrait) 
        return YES;
    else 
        return NO;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (IS_IPAD && self.popController.isPopoverVisible) {
        CGRect rect = CGRectMake((self.view.bounds.size.width/2), 1.0f, 1.0f, 1.0f);
        [self.popController presentPopoverFromRect:rect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

#pragma mark -
#pragma mark Custom methods

- (void)showPicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.navigationBar.translucent = NO;
    picker.sourceType = self.sourceType;
    picker.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
    picker.allowsEditing = NO;
    picker.delegate = self;
    
    if (IS_IPAD && self.sourceType != UIImagePickerControllerSourceTypeCamera) {
        self.popController = [[UIPopoverController alloc] initWithContentViewController:picker];
        popController.popoverBackgroundViewClass = [WPPopoverBackgroundView class];
        popController.delegate = self;
        CGRect rect = CGRectMake((self.view.frame.size.width/2), 1.0f, 1.0f, 1.0f); // puts the arrow in the middle of the screen
        [popController presentPopoverFromRect:rect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];            
        
    } else {
        picker.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self presentViewController:picker animated:YES completion:nil];
    }
}


- (void)handleKeyboardWillShow:(NSNotification *)notification {

    NSDictionary *info = notification.userInfo;

    keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect rect = [self.view convertRect:keyboardFrame fromView:self.view.window];

    CGRect frm = startingFrame;
    frm.size.height = rect.origin.y;

    self.view.frame = frm;
}


- (void)handleKeyboardWillHide:(NSNotification *)notification {
    self.view.frame = startingFrame;
    keyboardFrame = CGRectZero;
}

- (void)postInBackground {
    [post save];
}

- (void)post {
    [WPMobileStats trackEventForWPCom:StatsEventQuickPhotoPosted];
    
    Blog *blog = self.blogSelector.activeBlog;
    Media *media = nil;
    if (post == nil) {
        post = [Post newDraftForBlog:blog];
    } else {
        post.blog = blog;
        media = [post.media anyObject];
        [media setBlog:blog];
    }
    post.postTitle = titleTextField.text;
    post.content = contentTextView.text;
    if (self.isCameraPlus) {
        post.specialType = @"QuickPhotoCameraPlus";
    } else {
        post.specialType = @"QuickPhoto";
    }
    post.postFormat = @"image";
    
    if( appDelegate.connectionAvailable == YES ) {
        [[NSNotificationCenter defaultCenter] addObserver:post selector:@selector(mediaDidUploadSuccessfully:) name:ImageUploadSuccessful object:media];
        [[NSNotificationCenter defaultCenter] addObserver:post selector:@selector(mediaUploadFailed:) name:ImageUploadFailed object:media];
        
        appDelegate.isUploadingPost = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [media uploadWithSuccess:nil failure:nil];
            [post save];
        });
        
        [self dismiss];
        [sidebarViewController uploadQuickPhoto:post];
    } else {
        [media setRemoteStatus:MediaRemoteStatusFailed];
        [post save];
        [self dismiss];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Quick Photo Failed", @"")
                                                            message:NSLocalizedString(@"The Internet connection appears to be offline. The post has been saved as a local draft, you can publish it later.", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

- (void)dismiss {
    [[self sidebarViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancel {
    self.photo = nil;
    if (post != nil) {
        [post deletePostWithSuccess:nil failure:nil];
    }
    [self dismiss];
}


- (void)saveImage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        if (self.sourceType == UIImagePickerControllerSourceTypeCamera)
            UIImageWriteToSavedPhotosAlbum(self.photo, nil, nil, nil);
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            Media *media = nil;
            
            Blog *blog = self.blogSelector.activeBlog;
            if (post == nil) {
                post = [Post newDraftForBlog:blog];
            }
            
            if (post.media && [post.media count] > 0) {
                media = [post.media anyObject];
            } else {
                media = [Media newMediaForPost:post];
                int resizePreference = 0;
                if([[NSUserDefaults standardUserDefaults] objectForKey:@"media_resize_preference"] != nil)
                    resizePreference = [[[NSUserDefaults standardUserDefaults] objectForKey:@"media_resize_preference"] intValue];
                
                MediaResize newSize = kResizeLarge;
                switch (resizePreference) {
                    case 1:
                        newSize = kResizeSmall;
                        break;
                    case 2:
                        newSize = kResizeMedium;
                        break;
                    case 4:
                        newSize = kResizeOriginal;
                        break;
                }
                
                [media setImage:self.photo withSize:newSize];
            }
            
            [media save];
            [postButtonItem setEnabled:YES];
        });
    });
}


#pragma mark -
#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    // On iOS7 Beta 6 the image picker seems to override our preferred setting so we force the status bar color back.
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

    if (popController) {
        [popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    self.photo = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
    self.photoImageView.image = self.photo;
    
    if (![self isViewLoaded]) {
        // If we get a memory warning on the way here our view could have unloaded.
        // In order to prevet a crash we'll make sure its loaded before 
        // dismissing the modal. 
        [self view];
        [self.blogSelector loadBlogsForType:BlogSelectorButtonTypeQuickPhoto];
        self.blogSelector.delegate = self;
        
        // if the keyboard is showing we need to reset the height of the view as well.
        if (!CGRectEqualToRect(keyboardFrame, CGRectZero)) {
            CGRect frame = self.view.frame;
            frame.size.height = keyboardFrame.size.height;
            self.view.frame = frame;
        }
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self saveImage];
    
    [self.titleTextField performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.f];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    // On iOS7 Beta 6 the image picker seems to override our preferred setting so we force the status bar color back.
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

    if (popController) {
        [popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    picker.delegate = nil;
    [self dismiss];
}

#pragma mark - Blog selector delegate

- (void)blogSelectorButtonWillBecomeActive:(BlogSelectorButton *)button {
    [self.titleTextField resignFirstResponder];
    [self.contentTextView resignFirstResponder];
    [self.view bringSubviewToFront:button];
}

- (void)blogSelectorButtonDidBecomeInactive:(BlogSelectorButton *)button {
    [self.titleTextField becomeFirstResponder];
}

#pragma mark - Quick Photo preview view delegate

- (void)pictureWillZoom {
    [self.titleTextField resignFirstResponder];
    [self.contentTextView resignFirstResponder];
    [self.view bringSubviewToFront:photoImageView];
}

- (void)pictureDidRestore {
    [self.titleTextField becomeFirstResponder];
}

#pragma mark - UIPopoverViewController Delegate methods

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    // On iOS7 Beta 6 the image picker seems to override our preferred setting so we force the status bar color back.
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [self dismiss];
}

#pragma mark - UITextViewDelegate Methods

-(void)textViewDidBeginEditing:(UITextView *)textView {
    self.tapToBeginWritingLabel.hidden = YES;
}

-(void)textViewDidEndEditing:(UITextView *)textView {
    self.tapToBeginWritingLabel.hidden = (textView.text.length > 0);
}

@end
