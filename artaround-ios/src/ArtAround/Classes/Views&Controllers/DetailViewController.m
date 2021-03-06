//
//  DetailViewController.m
//  ArtAround
//
//  Created by Brandon Jones on 8/27/11.
//  Copyright 2011 ArtAround. All rights reserved.
//

#import "DetailViewController.h"
#import "Art.h"
#import "Comment.h"
#import "Event.h"
#import "Category.h"
#import "Neighborhood.h"
#import "DetailView.h"
#import "ArtAnnotation.h"
#import "Utilities.h"
#import "FlickrAPIManager.h"
#import "Photo.h"
#import "EGOImageButton.h"
#import <QuartzCore/QuartzCore.h>
#import "AAAPIManager.h"
#import "ItemParser.h"
#import "ArtParser.h"


@interface DetailViewController (private)

- (NSString *)yearString;
- (NSString *)category;
- (NSString *)artName;
- (NSString *)artistName;
- (NSString *)artDesctiption;
- (NSString *)locationDescription;

- (void)addImageButtonTapped;
- (void)favoriteButtonTapped;
- (void)submitCommentButtonTapped;
- (void)cancelButtonTapped;
- (void)flagButtonTapped;
- (void)shareOnTwitter;
- (void)shareOnFacebook;
- (void)showFBDialog;
- (void)shareViaEmail;
- (NSString *)shareMessage;
- (NSString *)shareURL;
- (void)showLoadingView:(NSString*)msg;
- (void) artButtonPressed:(id)sender;

- (BOOL)validateFieldsReadyToSubmit;
- (void)artUploadCompleted:(NSDictionary*)responseDict;
- (void)artUploadFailed:(NSDictionary*)responseDict;
- (void)artDownloadComplete;
- (void)photoUploadCompleted:(NSDictionary*)responseDict;
- (void)photoUploadFailed:(NSDictionary*)responseDict;
- (void)photoUploadCompleted;
- (void)photoUploadFailed;
- (void)commentUploadCompleted:(NSDictionary*)responseDict;
- (void)commentUploadFailed:(NSDictionary*)responseDict;

@end

#define _kAddImageActionSheet 100
#define _kShareActionSheet 101
#define _kFlagActionSheet 102
#define _kUserAddedImageTagBase 1000

static const float _kPhotoPadding = 5.0f;
static const float _kPhotoSpacing = 15.0f;
static const float _kPhotoInitialPaddingPortait = 64.0f;
static const float _kPhotoInitialPaddingForOneLandScape = 144.0f;
static const float _kPhotoInitialPaddingForTwoLandScape = 40.0f;
static const float _kPhotoInitialPaddingForThreeLandScape = 15.0f;
static const float _kPhotoWidth = 192.0f;
static const float _kPhotoHeight = 140.0f;

@implementation DetailViewController
@synthesize currentLocation;
@synthesize art = _art, detailView = _detailView;

- (id)init
{
	self = [super init];
    if (self) {
		
		//get a reference to the app delegate
		_appDelegate = (ArtAroundAppDelegate *)[[UIApplication sharedApplication] delegate];
		
		//observe notification for facebook login
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showFBDialog) name:@"fbDidLogin" object:nil];
        
        //initialize useraddedimages
        _userAddedImages = [[NSMutableArray alloc] init];
        
        //initialize edit mode
        _inEditMode = NO;
        
        //init show all mode
        _showAllComments = NO;
        
        //initialize addedImageCount
        _addedImageCount = 0;
        
    }
    return self;
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

//ensure that release is only called on the main thread
- (oneway void)release
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(release) withObject:nil waitUntilDone:NO];
    } else {
        [super release];
    }
}

- (void)dealloc
{
	[self.detailView.mapView setDelegate:nil];
	[self setArt:nil];
	[self setDetailView:nil];
	[super dealloc];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
	[super viewDidLoad];
    
	//setup the detail view
    DetailView *aDetailView = [[DetailView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
    [self setDetailView:aDetailView];
    [self.view addSubview:self.detailView];
    [self.detailView.tableView setDelegate:self];
    [self.detailView.tableView setDataSource:self];
    [self.detailView.mapView setDelegate:self];
    [self.detailView setEditMode:NO withCancel:NO];
    [self.detailView.rightButton addTarget:self action:@selector(bottomToolbarButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [aDetailView release];
    
    //add invisible back button to the logo on the toolbar
    _invBackButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    [_invBackButton setFrame:CGRectMake(0, 0, 80, self.navigationController.navigationBar.frame.size.height)];
    [_invBackButton setCenter:CGPointMake(self.navigationController.navigationBar.center.x, _invBackButton.center.y)];
    [_invBackButton setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
    [_invBackButton addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    [_invBackButton setShowsTouchWhenHighlighted:YES];
    [self.navigationController.navigationBar addSubview:_invBackButton];
    

    [self setInEditMode:_inEditMode];
    
    //share button
    /*if (_inEditMode) {
        
        //if there's already a share button disable it
        if ([self.navigationItem rightBarButtonItem] != nil) {
            
            [self.navigationItem.rightBarButtonItem setEnabled:NO];
        }
    }
    else {
        
        //if there's already a share button enable it
        //else add it
        if ([self.navigationItem rightBarButtonItem] != nil) {
            
            [self.navigationItem.rightBarButtonItem setEnabled:YES];
        }
        else {
            
            //add a share button to toolbar
            UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareButtonTapped)];
            [self.navigationItem setRightBarButtonItem:shareButton animated:YES];
            [shareButton release];
        }
    }*/
    
	
}

- (void)viewDidUnload
{
    
    [super viewDidUnload];
    
}

- (void) viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
    
    if (_inEditMode) {
        [Utilities trackPageViewWithName:[NSString stringWithFormat:@"ArtDetailView/%@", (_art.slug) ? _art.slug : @""]];
    }
    else {
        [Utilities trackPageViewWithName:@"AddViewArt"];
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    
    [super viewWillDisappear:animated];
    
    //get rid of the inv back button from the toolbar
    [_invBackButton removeFromSuperview];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
	//return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    
}


#pragma mark - View Controller Setup

- (void)setInEditMode:(BOOL)editMode 
{
    _inEditMode = editMode;
    
    if (editMode) {
        
        //if there's already a share button disable it
        if ([self.navigationItem rightBarButtonItem] != nil) {
            
            [self.navigationItem.rightBarButtonItem setEnabled:NO];
        }
        
        [self.detailView setEditMode:YES withCancel:(_art) ? YES : NO];
        
        [self.detailView.leftButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        //[self.detailView.rightButton addTarget:self action:@selector(bottomToolbarButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    else {
        
        //if there's already a share button enable it
        //else add it
        if ([self.navigationItem rightBarButtonItem] != nil) {
            
            [self.navigationItem.rightBarButtonItem setEnabled:YES];
        }
        else {
            
            //add a share button to toolbar
            UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareButtonTapped)];
            [self.navigationItem setRightBarButtonItem:shareButton animated:YES];
            [shareButton release];
        }
        
        [self.detailView setEditMode:NO withCancel:NO];
        

        //set the fav button selected or not
        [self.detailView.leftButton setSelected:NO];
        
        [self.detailView.leftButton addTarget:self action:@selector(favoriteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        [self.detailView.flagButton addTarget:self action:@selector(flagButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    
    
   [self.detailView.rightButton addTarget:self action:@selector(bottomToolbarButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    //reload the table
    [self.detailView.tableView reloadData];
}

- (void)setArt:(Art *)art
{
    [self setArt:art withTemplate:nil];
}

- (void)setArt:(Art *)art withTemplate:(NSString*)templateFileName 
{
    
    [self setArt:art withTemplate:templateFileName forceDownload:NO];
}

- (void)setArt:(Art *)art withTemplate:(NSString*)templateFileName forceDownload:(BOOL)force
{
	//assign the art
	_art = [art retain];
	
	//load images that we already have a source for
	[self setupImages];
	
	//get all the photo details for each photo that is missing the deets
	for (Photo *photo in [_art.photos allObjects]) {
		if (!photo.thumbnailSource || [photo.thumbnailSource isEqualToString:@""]) {
			//[[FlickrAPIManager instance] downloadPhotoWithID:photo.flickrID target:self callback:@selector(setupImages)];
            [[AAAPIManager instance] downloadArtForSlug:art.slug target:self callback:@selector(setupImage) forceDownload:YES];
		}
	}
    
    //download the full art object
    if (art) {
        //get the comments for this art
        [[AAAPIManager instance] downloadArtForSlug:_art.slug target:self callback:@selector(artDownloadComplete) forceDownload:force];
    }
	
	//add the annotation for the art
	if ([_art.latitude doubleValue] && [_art.longitude doubleValue]) {
		
		//setup the coordinate
		CLLocationCoordinate2D artLocation;
		artLocation.latitude = [art.latitude doubleValue];
		artLocation.longitude = [art.longitude doubleValue];
		
		//create an annotation, add it to the map, and store it in the array
		ArtAnnotation *annotation = [[ArtAnnotation alloc] initWithCoordinate:artLocation title:art.title subtitle:art.artist];
		[self.detailView.mapView addAnnotation:annotation];
		[annotation release];
		
	}
    
    //reload the table
    [self.detailView.tableView reloadData];
    
    //check the favorite
    if (!_inEditMode) 
        [self.detailView.leftButton setSelected:[_art.favorite boolValue]];
    
}

- (void)setupImages
{
	//loop through all the images and add an image view if it doesn't exist yet
	//update the url for each image view that doesn't have one yet
	//this method may be called multiple times as the flickr api returns info on each photo
    //insert the add button at the end of the scroll view
	EGOImageButton *prevView = nil;
	int totalPhotos = (_art && _art.photos != nil) ? [_art.photos count] + _userAddedImages.count : _userAddedImages.count;
	int photoCount = 0;
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES]];
	NSArray * sortedPhotos = [_art.photos sortedArrayUsingDescriptors:sortDescriptors];
    
    for (Photo *photo in sortedPhotos) {
		
		//adjust the image view y offset
		float prevOffset = _kPhotoPadding;
		if (prevView) {
			
			//adjust offset based on the previous frame
			prevOffset = prevView.frame.origin.x + prevView.frame.size.width + _kPhotoSpacing;
			
		} else {
			
			//adjust the initial offset based on the total number of photos
			BOOL isPortrait = (UIInterfaceOrientationIsPortrait(self.interfaceOrientation));
			if (isPortrait) {
				prevOffset = _kPhotoInitialPaddingPortait;
			} else {
				
				switch (totalPhotos) {
					case 1:
						prevOffset = _kPhotoInitialPaddingForOneLandScape;
						break;
						
					case 2:
						prevOffset = _kPhotoInitialPaddingForTwoLandScape;
						break;
						
					case 3:
					default:
						prevOffset = _kPhotoInitialPaddingForThreeLandScape;
						break;
				}
				
			}
            
		}
		
		//grab existing or create new image view
		EGOImageButton *imageView = (EGOImageButton *)[self.detailView.photosScrollView viewWithTag:(10 + [[_art.photos sortedArrayUsingDescriptors:sortDescriptors] indexOfObject:photo])];
		if (!imageView) {
			imageView = [[EGOImageButton alloc] initWithPlaceholderImage:nil];
			[imageView setTag:(10 + [[_art.photos sortedArrayUsingDescriptors:sortDescriptors] indexOfObject:photo])];
			[imageView setFrame:CGRectMake(prevOffset, _kPhotoPadding, _kPhotoWidth, _kPhotoHeight)];
			[imageView setClipsToBounds:YES];
			[imageView.imageView setContentMode:UIViewContentModeScaleAspectFill];
			[imageView setBackgroundColor:[UIColor lightGrayColor]];
			[imageView.layer setBorderColor:[UIColor whiteColor].CGColor];
			[imageView.layer setBorderWidth:6.0f];
            [imageView addTarget:self action:@selector(artButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
			[self.detailView.photosScrollView addSubview:imageView];
			[imageView release];
		}
		
		//set the image url 
		if (imageView) {
			[imageView setImageURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kArtAroundURL, photo.originalURL]]];
		}
		
		//adjust the imageView autoresizing masks when there are fewer than 3 images so that they stay centered
		if (imageView && totalPhotos < 3) {
			[imageView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
		}
		
		//store the previous view for reference
		//increment photo count
		prevView = imageView;
		photoCount++;
		
	}
    
    for (UIImage *thisUserImage in _userAddedImages) {
		
		//adjust the image view y offset
		float prevOffset = _kPhotoPadding;
		if (prevView) {
            
			//adjust offset based on the previous frame
			prevOffset = prevView.frame.origin.x + prevView.frame.size.width + _kPhotoSpacing;
			
		} else {
			
			//adjust the initial offset based on the total number of photos
			BOOL isPortrait = (UIInterfaceOrientationIsPortrait(self.interfaceOrientation));
			if (isPortrait) {
				prevOffset = _kPhotoInitialPaddingPortait;
			} else {
				
				switch (totalPhotos) {
					case 1:
						prevOffset = _kPhotoInitialPaddingForOneLandScape;
						break;
						
					case 2:
						prevOffset = _kPhotoInitialPaddingForTwoLandScape;
						break;
						
					case 3:
					default:
						prevOffset = _kPhotoInitialPaddingForThreeLandScape;
						break;
				}
				
			}
            
		}
		
		//grab existing or create new image view
		EGOImageButton *imageView = (EGOImageButton *)[self.detailView.photosScrollView viewWithTag:(_kUserAddedImageTagBase + [_userAddedImages indexOfObject:thisUserImage])];
		if (!imageView) {
			imageView = [[EGOImageButton alloc] initWithPlaceholderImage:nil];
			[imageView setTag:(_kUserAddedImageTagBase + [_userAddedImages indexOfObject:thisUserImage])];
			[imageView setFrame:CGRectMake(prevOffset, _kPhotoPadding, _kPhotoWidth, _kPhotoHeight)];
			[imageView setClipsToBounds:YES];
			[imageView.imageView setContentMode:UIViewContentModeScaleAspectFill];
			[imageView setBackgroundColor:[UIColor lightGrayColor]];
			[imageView.layer setBorderColor:[UIColor whiteColor].CGColor];
			[imageView.layer setBorderWidth:6.0f];
            [imageView addTarget:self action:@selector(artButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
			[self.detailView.photosScrollView addSubview:imageView];
			[imageView release];
            
		}
		
		//set the image url if it doesn't exist yet
		if (imageView && !imageView.imageURL) {
			[imageView setImage:thisUserImage forState:UIControlStateNormal];
		}
		
		//adjust the imageView autoresizing masks when there are fewer than 3 images so that they stay centered
		if (imageView && totalPhotos < 3) {
			[imageView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
		}
		
		//store the previous view for reference
		//increment photo count
		prevView = imageView;
		photoCount++;
		
	}
	
    //get the add button's offset
    float prevOffset = _kPhotoPadding;
    if (prevView) {
        //adjust offset based on the previous frame
        prevOffset = prevView.frame.origin.x + prevView.frame.size.width + _kPhotoSpacing;
        
    } else {
        
        //adjust the initial offset based on the total number of photos
        BOOL isPortrait = (UIInterfaceOrientationIsPortrait(self.interfaceOrientation));
        if (isPortrait) {
            prevOffset = _kPhotoInitialPaddingPortait;
        } else {
            prevOffset = _kPhotoInitialPaddingForOneLandScape;
        }
    }
    
    //setup the add image button
    UIButton *addImgButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [addImgButton setFrame:CGRectMake(prevOffset, _kPhotoPadding, _kPhotoWidth, _kPhotoHeight)];
    [addImgButton setImage:[UIImage imageNamed:@"uploadPhoto_noBg.png"] forState:UIControlStateNormal];
    [addImgButton.imageView setContentMode:UIViewContentModeCenter];
    [addImgButton.layer setBorderColor:[UIColor whiteColor].CGColor];
    [addImgButton.layer setBorderWidth:6.0f];
    [addImgButton setBackgroundColor:[UIColor lightGrayColor]];
    [addImgButton addTarget:self action:@selector(addImageButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    //adjust the button's autoresizing mask when there are fewer than 3 images so that it stays centered
    if (totalPhotos < 3) {
        [addImgButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
    }
    
    [self.detailView.photosScrollView addSubview:addImgButton];
    
	//set the content size
	[self.detailView.photosScrollView setContentSize:CGSizeMake(addImgButton.frame.origin.x + addImgButton.frame.size.width + _kPhotoSpacing, self.detailView.photosScrollView.frame.size.height)];
	
	
}


- (NSString*)buildHTMLString 
{
    //setup the template
	NSString *templatePath = [[NSBundle mainBundle] pathForResource:(_inEditMode) ? @"AddDetailView" : @"DetailView" ofType:@"html"];
	NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];
    NSString *html = [[NSString alloc] initWithString:template];
    
    //setup attribute values
    //don't show "0" year
    NSString *year = (_art.year && [_art.year intValue] != 0) ? [_art.year stringValue] : @"Unknown";
    NSString *artTitle = (_art.title) ? _art.title : @"";
    NSString *artist = (_art.artist) ? _art.artist : @"";
    NSString *category = (_art.categories && [_art categoriesString]) ? [_art categoriesString] : @"";
    NSString *neighborhood = (_art.neighborhood && _art.neighborhood.title) ? _art.neighborhood.title : @"";
    NSString *ward = (_art.ward) ? [_art.ward stringValue] : @"";
    NSString *locationDesc = (_art.locationDescription) ? _art.locationDescription : @"";    
    
    if (_inEditMode) {
        
        //get the categories
        NSMutableArray *catsArray = [[NSMutableArray alloc] initWithArray:[[[AAAPIManager instance] categories] copy]];
        
        //don't include the "all" category
        [catsArray removeObject:@"All"];
        
        //setup categories
        NSString *categoriesString = @"";    
        for (NSString *cat in catsArray) {
            
            //check to see if this is the current neighborhood
            BOOL selectedOption = ([[cat lowercaseString] isEqualToString:[category lowercaseString]]);
            
            categoriesString = [NSString stringWithFormat:@"%@<option%@ value=\"%@\">%@</option>", categoriesString, (selectedOption) ? @" selected=\"selected\"" : @"", cat, cat, nil];
        }
        [catsArray release];
        
        
        //get the neighborhoods
        NSMutableArray *neighborhoodsArray = [[NSMutableArray alloc] initWithArray:[[[AAAPIManager instance] neighborhoods] copy]];
        
        //don't include the "all" category
        [neighborhoodsArray removeObject:@""];
        [neighborhoodsArray removeObject:@"All"];
        
        //setup categories
        NSString *neighborhoodsString = @"";    
        for (NSString *n in neighborhoodsArray) {
            
            //check to see if this is the current neighborhood
            BOOL selectedOption = ([[n lowercaseString] isEqualToString:[neighborhood lowercaseString]]);
            
            neighborhoodsString = [NSString stringWithFormat:@"%@<option%@ value=\"%@\">%@</option>", neighborhoodsString, (selectedOption) ? @" selected=\"selected\"" : @"", n, n, nil];
            
        }
        [neighborhoodsArray release];
        
        //setup html
        html = [NSString stringWithFormat:template, artTitle, artist, year, categoriesString, neighborhoodsString, ward, locationDesc, [NSString stringWithFormat:@"%f",self.currentLocation.coordinate.latitude], [NSString stringWithFormat:@"%f",self.currentLocation.coordinate.longitude], nil];
    }
    else {
        
        NSString *favButtonImageSrc = ([_art.favorite boolValue]) ? @"FavoriteButtonSelected.png" : @"FavoriteButton.png";
        
        //setup html
        html = [NSString stringWithFormat:html, favButtonImageSrc, artTitle, artist, year, category, neighborhood, ward, locationDesc];
        
    }
    
    return html;
}

//present the loading view
- (void)showLoadingView:(NSString*)msg
{
    //display loading alert view
    if (!_loadingAlertView) {
        _loadingAlertView = [[UIAlertView alloc] initWithTitle:msg message:nil delegate:self cancelButtonTitle:nil otherButtonTitles: nil];
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        indicator.tag = 10;
        // Adjust the indicator so it is up a few pixels from the bottom of the alert
        indicator.center = CGPointMake(_loadingAlertView.bounds.size.width / 2, _loadingAlertView.bounds.size.height - 50);
        indicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        [indicator startAnimating];
        [_loadingAlertView addSubview:indicator];
        [indicator release];
    }
    
    [_loadingAlertView setTitle:msg];
    [_loadingAlertView show];
    
    
    
    //display an activity indicator view in the center of alert
    UIActivityIndicatorView *activityView = (UIActivityIndicatorView*)[_loadingAlertView viewWithTag:10];
    [activityView setCenter:CGPointMake(_loadingAlertView.bounds.size.width / 2, _loadingAlertView.bounds.size.height - 44)];
    [activityView setFrame:CGRectMake(roundf(activityView.frame.origin.x), roundf(activityView.frame.origin.y), activityView.frame.size.width, activityView.frame.size.height)];
}


#pragma mark - Action's
- (void) artButtonPressed:(id)sender
{
    EGOImageButton *button = (EGOImageButton*)sender;
    int buttonTag = button.tag;
    
    //get this photo
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"dateAdded" ascending:YES]];
	NSArray * sortedPhotos = [_art.photos sortedArrayUsingDescriptors:sortDescriptors];
    Photo *thisPhoto = [sortedPhotos objectAtIndex:buttonTag - 10];

    PhotoImageView *imgView = [[PhotoImageView alloc] initWithFrame:CGRectOffset(self.view.frame, 0, 0)];
    [imgView setPhotoImageViewDelegate:self];
    [imgView setContentMode:UIViewContentModeScaleAspectFit];
    [imgView setBackgroundColor:kFontColorDarkBrown];
    
    if (button.imageView.image)
        [imgView setImage:button.imageView.image];
    else {
        if (thisPhoto.originalURL)
            [imgView setImageURL:button.imageURL];
    }

    //set the photo attribution if they exist
    if (thisPhoto.photoAttribution) {
        [(UILabel*)[imgView.photoAttributionButton viewWithTag:kAttributionButtonLabelTag] setText:[NSString stringWithFormat:@"Photo by %@", thisPhoto.photoAttribution]];
    }
    else {
        [(UILabel*)[imgView.photoAttributionButton viewWithTag:kAttributionButtonLabelTag] setText:@"Photo by anonymous user"];
    }
    
    if (thisPhoto.photoAttributionURL && [thisPhoto.photoAttributionURL isKindOfClass:[NSString class]] && thisPhoto.photoAttributionURL.length > 0) {
        [imgView setUrl:[NSURL URLWithString:thisPhoto.photoAttributionURL]];
    }

    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view = imgView;

    [self.navigationController pushViewController:viewController animated:YES];
    DebugLog(@"Button Origin: %f", imgView.photoAttributionButton.frame.origin.y);
    [imgView release];
    [viewController release];
             
    
}

- (void) flagButtonTapped
{
    
    UIActionSheet *flagSheet = [[UIActionSheet alloc] initWithTitle:@"Flag Art" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Incorrect Info", @"Missing / Damaged", @"Duplicate", nil];
    [flagSheet setTag:_kFlagActionSheet];
    [flagSheet showInView:self.view];
    [flagSheet release];

    
}

- (void)bottomToolbarButtonTapped
{
    
    if (_inEditMode) {
        
        //validate title/category field
        if (![self validateFieldsReadyToSubmit]) {
            UIAlertView *todoAlert = [[UIAlertView alloc] initWithTitle:@"Need More Info" message:@"All art must have a title and category before submission." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [todoAlert show];
            return;
        }

        //create the art parameters dictionary
        if (_newArtDictionary) {
            _newArtDictionary = nil, [_newArtDictionary release];
        }
        
        //init the new dict with the art name, category, and location
        _newArtDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[Utilities urlEncode:[self artName]], @"title", [Utilities urlEncode:[self category]], @"category", nil];
        
                
        //get the year if it exists
        if ([self yearString] && [[self yearString] length] > 0)
            [_newArtDictionary setObject:[Utilities urlEncode:[self yearString]] forKey:@"year"];
        
        //get the artist if it exists
        if ([self artistName] && [[self artistName] length] > 0)
            [_newArtDictionary setObject:[Utilities urlEncode:[self artistName]] forKey:@"artist"];
        
        //get the description if it exists
        if ([self artDesctiption] && [[self artDesctiption] length] > 0)
            [_newArtDictionary setObject:[Utilities urlEncode:[self artDesctiption]] forKey:@"description"];        
        
        //get the location description if it exists
        if ([self locationDescription] && [[self locationDescription] length] > 0)
            [_newArtDictionary setObject:[Utilities urlEncode:[self locationDescription]] forKey:@"location_description"];        
        
        
        //if this is an update - add the existing slug and submit 
        //else add the location and submit
        if (_art.slug && _art.slug.length > 0) {  
            
            [_newArtDictionary setValue:[Utilities urlEncode:_art.slug] forKey:@"slug"];
            
            //call the submit request
            [[AAAPIManager instance] updateArt:_newArtDictionary withTarget:self callback:@selector(artUploadCompleted:) failCallback:@selector(artUploadFailed:)];
            
            //show loading view
            [self showLoadingView:@"Updating Art\nPlease Wait..."];
        
        }
        else {
            
            //[_newArtDictionary setValue:_art.slug forKey:@"slug"];

            //add location
            [_newArtDictionary setValue:self.currentLocation forKey:@"location[]"];
            
            
            //call the submit request
            [[AAAPIManager instance] submitArt:_newArtDictionary withTarget:self callback:@selector(artUploadCompleted:) failCallback:@selector(artUploadFailed:)];
            
            //show loading view
            [self showLoadingView:@"Uploading Art\nPlease Wait..."];
            
        }
        
        
    }
    else {
        [self setInEditMode:YES];
        [self.detailView.tableView reloadData];
    }
    
}

//return YES if title & category have been filled in; no otherwise
- (BOOL)validateFieldsReadyToSubmit
{
    NSLog(@"CAT: %@ NAME: %@", [self category], [self artName], nil);
    //make sure the title and category have been selected
    if ([[self category] length] > 0 && [[self artName] length] > 0)
        return YES;
    else
        return NO;
}

- (void)favoriteButtonTapped {
    
    //switch the art's favorite property
    [ArtParser setFavorite:![_art.favorite boolValue] forSlug:_art.slug];
    
    //merge context
    [[AAAPIManager instance] performSelectorOnMainThread:@selector(mergeChanges:) withObject:[NSNotification notificationWithName:NSManagedObjectContextDidSaveNotification object:[AAAPIManager managedObjectContext]] waitUntilDone:YES];
    
    //update the button
    [self.detailView.leftButton setSelected:([_art.favorite boolValue])];
    
    //refresh the mapview so that the updated favorites are showing
    ArtAroundAppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
    [appDelegate saveContext];
    [appDelegate.mapViewController updateArt];
    
    
}


- (void)userAddedImage:(UIImage*)image
{
    //increment the number of new images
    _addedImageCount += 1;
    
    if (_inEditMode) {
        [_userAddedImages addObject:image];
    }
    else {
        
        //upload image
        [[AAAPIManager instance] uploadImage:image forSlug:self.art.slug withFlickrHandle:[Utilities instance].photoAttributionText withPhotoAttributionURL:@"" withTarget:self callback:@selector(photoUploadCompleted:) failCallback:@selector(photoUploadFailed:)];
        
        [self showLoadingView:@"Uploading Photo\nPlease Wait..."];
    }
    
    //reload the images to show the new image
    [self setupImages];    
}

- (void)submitCommentButtonTapped
{
    for (int row = 1; row < 4; row++) {
        if ([(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]] viewWithTag:row] isFirstResponder])
            [(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]] viewWithTag:row] resignFirstResponder];
    }
    
    if ([(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:3]] viewWithTag:1] isFirstResponder])
        [(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:3]] viewWithTag:1] resignFirstResponder];
    
    
    //set the tableview inset back to the original size
    [UIView beginAnimations:nil context:nil];
    [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
    [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)]; 
    [UIView commitAnimations];
    
    if ([[_newCommentDictionary objectForKey:@"text"] length] > 0 && [[_newCommentDictionary objectForKey:@"email"] length] > 0 && [[_newCommentDictionary objectForKey:@"name"] length] > 0) {
        
        //upload the comment
        [[AAAPIManager instance] uploadComment:_newCommentDictionary forSlug:_art.slug target:self callback:@selector(commentUploadCompleted:) failCallback:@selector(commentUploadFailed:)];
        
        //show loading view
        [self showLoadingView:@"Submitting Comment\nPlease Wait..."];
        
    }
    else {
        UIAlertView *noDataAlert = [[UIAlertView alloc] initWithTitle:@"Missing Data" message:@"To submit a comment you have to enter a Name, Email Address, and a Comment" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [noDataAlert show];
        [noDataAlert release];
    }
    
    
}

- (void)cancelButtonTapped {
    [self setInEditMode:NO];
}

- (void) closeModalViewController:(id)sender
{
    if (self.modalViewController) {
        [self dismissModalViewControllerAnimated:YES];
    }
}

#pragma mark - UIWebViewDelegate
/*
 - (void)webViewDidStartLoad:(UIWebView *)webView 
 {
 }
 
 - (void)webViewDidFinishLoad:(UIWebView *)webView
 {
 
 //set a native style scroll speed
 for (UIView *subview in [webView subviews]) {
 if ([subview isKindOfClass:NSClassFromString(@"UIScroller")] || [subview isKindOfClass:NSClassFromString(@"UIScrollView")]) {
 if ([subview respondsToSelector:@selector(setDecelerationRate:)]) {
 [(UIScrollView *)subview setDecelerationRate:UIScrollViewDecelerationRateNormal];
 }
 break;
 }
 }
 }
 
 - (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
 {	
 //url location
 NSString *url = [[request URL] absoluteString];
 
 //video play link
 if ([url rangeOfString:@"artaround://favoriteButtonTapped"].location != NSNotFound) {
 [self favoriteButtonTapped];
 return NO;
 }
 
 return YES;
 }
 
 - (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
 {
 DebugLog(@"detailController webview error:", error);
 }
 */

 
 #pragma mark - Gather ArtInfo from Webview
 
 - (NSString *)yearString
 {
     return [_yearField text];
 }
 
 - (NSString *)category
{
    return _categoryField.text;
    
 }
 
 - (NSString *)artName
 {
     //if this is a update, grab the existing title
     //else grab the user input
     if (_artNameField) {
         return _artNameField.text;
     }
     else {
         return _art.title;
     }
     
     
 }
 
 - (NSString *)artistName
 {
     return [_artistField text];
 }

- (NSString *)artDesctiption
{
    return [_artDescriptionView text];
}

- (NSString *)locationDescription
{

    return [_locationDescriptionView text];
}


#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
	[Utilities zoomToFitMapAnnotations:mapView];
}

#pragma mark - AddImageButton
- (void)addImageButtonTapped
{
    
    UIActionSheet *imgSheet = [[UIActionSheet alloc] initWithTitle:@"Upload Photo" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Take a Photo", @"Camera roll", nil];
    [imgSheet setTag:_kAddImageActionSheet];
    [imgSheet showInView:self.view];
    [imgSheet release];
    
}

#pragma mark - Share

- (void)shareButtonTapped
{
	//show an action sheet with the various sharing types
	UIActionSheet *shareSheet = [[UIActionSheet alloc] initWithTitle:@"Share This Item" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Email", @"Twitter", @"Facebook", nil];
    [shareSheet setTag:_kShareActionSheet];
	[shareSheet showInView:self.view];
	[shareSheet release];
}

- (void)shareViaEmail
{
	if ([MFMailComposeViewController canSendMail]) {
		
		//present the mail composer
		MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
		mailController.mailComposeDelegate = self;
		[mailController setSubject:@"Art Around"];
		[mailController setMessageBody:[self shareMessage] isHTML:NO];
		[self presentModalViewController:mailController animated:YES];
		[mailController release];
		
	} else {
		
		//this device can't send email
		UIAlertView *emailAlert = [[UIAlertView alloc] initWithTitle:@"Email Error" message:@"This device is not configured to send email." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
		[emailAlert show];
		[emailAlert release];
		
	}
}

- (void)shareOnTwitter
{
	//share on twitter in the browser
	NSString *twitterShare = [NSString stringWithFormat:@"http://twitter.com/share?text=%@", [[self shareMessage] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:twitterShare]];
}

- (void)shareOnFacebook
{
	//do we have a reference to the facebook object?
	if (!_facebook) {
		
		//get a reference to the facebook object
		_facebook = _appDelegate.facebook;
        
		
		//make sure the access token is properly set if we previously saved it
		NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
		NSString *accessToken = [prefs stringForKey:@"FBAccessTokenKey"];
		NSDate *expirationDate = [prefs objectForKey:@"FBExpirationDateKey"];
		[_facebook setAccessToken:accessToken];
		[_facebook setExpirationDate:expirationDate];
		
	}
	
	//make sure we have a valid reference to the facebook object
	if (!_facebook) {
		[_appDelegate fbDidNotLogin:NO];
		return;
	}
	
	//make sure we are authorized
	if (![_facebook isSessionValid]) {
		NSArray* permissions =  [NSArray arrayWithObjects:@"publish_stream", nil];
		[_facebook authorize:permissions];
	} else {
		[self showFBDialog];
	}
}

- (void)showFBDialog
{
	//make sure we have a valid reference to the facebook object
	if (!_facebook) {
		[_appDelegate fbDidNotLogin:NO];
		return;
	}
	
	//grab the first photo
	NSString *photoURL = @"";
	if (_art.photos && [_art.photos count] > 0) {
		Photo *photo = [[_art.photos allObjects] objectAtIndex:0];
		photoURL = photo.thumbnailSource;
	}
	
	//setup the parameters with info about this art
	NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								   @"Share on Facebook",  @"user_message_prompt",
								   [self shareURL], @"link",
								   photoURL, @"picture",
								   nil];
	
	//show the share dialog
	[_facebook dialog:@"feed" andParams:params andDelegate:self];
}

- (NSString *)shareMessage
{
	return [NSString stringWithFormat:@"Art Around: %@", [self shareURL]];
}

- (NSString *)shareURL
{
	return [NSString stringWithFormat:@"http://theartaround.us/arts/%@", _art.slug];
}

#pragma mark - FBDialogDelegate

- (void)dialogDidSucceed:(FBDialog*)dialog
{
	if ([dialog class] == [FBLoginDialog class]) {
		[self showFBDialog];
	}
}




#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    //switch on the action sheet tag
    switch (actionSheet.tag) {
        case _kAddImageActionSheet:
        {
            
            //decide what the picker's source is
            switch (buttonIndex) {
                    
                case 0:
                {
                    UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
                    imgPicker.delegate = self;
                    imgPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                    [self presentModalViewController:imgPicker animated:YES];
                    break;
                }
                case 1:
                {
                    UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
                    imgPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                    imgPicker.delegate = self;
                    [self presentModalViewController:imgPicker animated:YES];
                    break;
                }	
                default:
                    break;
            }
            
            break;
        }
        case _kShareActionSheet:
        {
            //decide what to do based on the button index
            switch (buttonIndex) {
                    
                    //share via email
                case AAShareTypeEmail:
                    [self shareViaEmail];
                    break;
                    
                    //share via twitter
                case AAShareTypeTwitter:
                    [self shareOnTwitter];
                    break;
                    
                    //share via facebook
                case AAShareTypeFacebook:
                    [self shareOnFacebook];
                    break;
                    
                default:
                    break;
            }
            
            break;
        }
        case _kFlagActionSheet:
        {
            //break on cancel
            if (buttonIndex == 3) break;
            
            FlagViewController *flagController = [[FlagViewController alloc] initWithNibName:@"FlagViewController" bundle:[NSBundle mainBundle]];
            flagController.view.autoresizingMask = UIViewAutoresizingNone;
            flagController.delegate = self;
            
            [self.view addSubview:flagController.view];
            [self.navigationItem.backBarButtonItem setEnabled:NO];   
            [self.navigationItem.rightBarButtonItem setEnabled:NO];

            break;
        }
        default:
            break;
    }
    
	
}

#pragma mark - Photo Upload Callback Methods 

- (void)photoUploadCompleted
{
    _addedImageCount -= 1;
    
    //dismiss the alert view
    [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
    
}

- (void)photoUploadFailed
{
    _addedImageCount -= 1;
    
    //dismiss the alert view
    [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
    
}


- (void)photoUploadCompleted:(NSDictionary*)responseDict
{
    if ([responseDict objectForKey:@"slug"]) {
        
        //parse the art object returned and update this controller instance's art
        [[AAAPIManager managedObjectContext] lock];
        //_art = [[ArtParser artForDict:responseDict inContext:[AAAPIManager managedObjectContext]] retain];
        [self setArt:[[ArtParser artForDict:responseDict inContext:[AAAPIManager managedObjectContext]] retain]];
        [[AAAPIManager managedObjectContext] unlock];
        
        //merge context
        [[AAAPIManager instance] performSelectorOnMainThread:@selector(mergeChanges:) withObject:[NSNotification notificationWithName:NSManagedObjectContextDidSaveNotification object:[AAAPIManager managedObjectContext]] waitUntilDone:YES];
    }
    else {
        [self photoUploadFailed:responseDict];
        return;
    }
    
    _addedImageCount -= 1;
    
    //if there are no more photo upload requests processing 
    //switch out of edit mode
    if (_addedImageCount == 0) {
        [self setInEditMode:NO];
        
        //dismiss the alert view
        [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
        
        //reload the map view so the updated/new art is there
        ArtAroundAppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
        [appDelegate saveContext];
        [appDelegate.mapViewController updateArt];
        
        //clear the user added images array
        [_userAddedImages removeAllObjects];
    }
    
    
}

- (void)photoUploadFailed:(NSDictionary*)responseDict
{
    _addedImageCount -= 1;    
    
    //dismiss the alert view
    [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
    
    
}


#pragma mark - Art Upload Callback Methods

- (void)artUploadCompleted:(NSDictionary*)responseDict
{
    //flag to check if this was an edit or a new submission
    BOOL newArt = NO;
    
    if ([responseDict objectForKey:@"success"]) {
        
        //parse new art and update this controller instance's art
        //grab the newly created slug if this is a creation
        if (!_art.slug) {
            [_newArtDictionary setObject:[responseDict objectForKey:@"success"] forKey:@"slug"];
            
            //it was new art
            newArt = YES;
        }
        
        //decode the objects
        for (NSString *thisKey in [_newArtDictionary allKeys]) {
            if ([[_newArtDictionary objectForKey:thisKey] isKindOfClass:[NSString class]])
                [_newArtDictionary setValue:[Utilities urlDecode:[_newArtDictionary objectForKey:thisKey]] forKey:thisKey];
        }
        
        [[AAAPIManager managedObjectContext] lock];
        _art = [[ArtParser artForDict:_newArtDictionary inContext:[AAAPIManager managedObjectContext]] retain];
        [[AAAPIManager managedObjectContext] unlock];
        
        //merge context
        [[AAAPIManager instance] performSelectorOnMainThread:@selector(mergeChanges:) withObject:[NSNotification notificationWithName:NSManagedObjectContextDidSaveNotification object:[AAAPIManager managedObjectContext]] waitUntilDone:YES];
        [(id)[[UIApplication sharedApplication] delegate] saveContext];
        
    }
    else {
        [self artUploadFailed:responseDict];
        return;
    }
    
    
    //if there are user added images upload them
    if (_userAddedImages.count > 0) {
        for (UIImage *thisImage in _userAddedImages) {
            [[AAAPIManager instance] uploadImage:thisImage forSlug:self.art.slug withFlickrHandle:[Utilities instance].photoAttributionText withPhotoAttributionURL:@"" withTarget:self callback:@selector(photoUploadCompleted:) failCallback:@selector(photoUploadFailed:)];
        }
    }
    else {
        //take out of edit mode
        [self setInEditMode:NO];
        
        //dismiss loadign view
        [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
        
        if (!newArt) {
            UIAlertView *moderationComment = [[UIAlertView alloc] initWithTitle:@"Thanks for your edit! Our moderators will approve it shortly" message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [moderationComment show];
        }
        
        //reload the map view so the updated/new art is there
        ArtAroundAppDelegate *appDelegate = (id)[[UIApplication sharedApplication] delegate];
        [appDelegate saveContext];
        [appDelegate.mapViewController refreshArt];
        
    }
    
}

- (void)artUploadFailed:(NSDictionary*)responseDict
{
    //dismiss loading view
    [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
    
    //show fail alert
    UIAlertView *failedAlertView = [[UIAlertView alloc] initWithTitle:@"Upload Failed" message:@"The upload failed. Please try again." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [failedAlertView show];
    [failedAlertView release];
}

#pragma mark - Art Download Callback Methods
- (void)artDownloadComplete 
{
    
    //if there are entities in the dictionary reset the art, force a downlod, and reset the dictionary
    //else just reset the art
    if (_newCommentDictionary && [_newCommentDictionary count] > 0) {
        
        //reload the art with newly downloaded comments
        [self setArt:_art withTemplate:nil forceDownload:YES];
        
        //reset comment dictionary
        _newCommentDictionary = nil, [_newCommentDictionary release];
    }
    else {
        
        //reload the art
        [self setArt:_art];
    }
}

#pragma mark - Comment Upload Callback Methods

- (void)commentUploadCompleted:(NSDictionary*)responseDict
{
    
    //check for success
    if ([[responseDict objectForKey:@"success"] boolValue]) {
    
    //clear the comment fields
    for (int row = 1; row < 4; row++) {
        [(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]] viewWithTag:row + 10] setText:@""];
    }
    [(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:3]] viewWithTag:11] setText:@""];
    
    
    //get the comments for this art
    [[AAAPIManager instance] downloadArtForSlug:_art.slug target:self callback:@selector(artDownloadComplete) forceDownload:YES];
    
    //dismiss alert
    [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
    }
    else {
        [self commentUploadFailed:responseDict];
    }
}

- (void)commentUploadFailed:(NSDictionary*)responseDict
{

    //dismiss loading view
    [_loadingAlertView dismissWithClickedButtonIndex:0 animated:YES];
    
    //show fail alert
    UIAlertView *failedAlertView = [[UIAlertView alloc] initWithTitle:@"Submission Failed" message:@"Please try again." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [failedAlertView show];
    [failedAlertView release];
    
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{
	//dismiss the mail composer
	[self becomeFirstResponder];
	[self dismissModalViewControllerAnimated:YES];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    //dismiss the picker view
    [self dismissViewControllerAnimated:YES completion:^{
        
    
    
    // Get the image from the result
    UIImage* image = [[info valueForKey:@"UIImagePickerControllerOriginalImage"] retain];
    
    //if the user has already been asked for a flickr handle just add image    
    if ([Utilities instance].lastFlickrUpdate) {
    
        //add image to user added images array
        [_userAddedImages addObject:image];
        
        [self userAddedImage:image];
        
    }
    else {  //if this is the first upload then prompt for their flickr handle
        
        FlickrNameViewController *flickrNameController = [[FlickrNameViewController alloc] initWithNibName:@"FlickrNameViewController" bundle:[NSBundle mainBundle]];
        [flickrNameController setImage:image];        
        flickrNameController.view.autoresizingMask = UIViewAutoresizingNone;
        flickrNameController.delegate = self;
        
        [self.view addSubview:flickrNameController.view];
        [self.navigationItem.backBarButtonItem setEnabled:NO];
        [self.navigationItem.rightBarButtonItem setEnabled:NO];
        
    }
        
    }];
    
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    [self dismissViewControllerAnimated:YES completion:^{
        
    
    
    //if the user has already been asked for a flickr handle just add image
    if ([Utilities instance].lastFlickrUpdate) {
        
        //add image to user added images array
        [_userAddedImages addObject:image];
        
        [self userAddedImage:image];
        
    }
    else {  //if this is the first upload then prompt for their flickr handle
        
        FlickrNameViewController *flickrNameController = [[FlickrNameViewController alloc] initWithNibName:@"FlagViewController" bundle:[NSBundle mainBundle]];
        [flickrNameController setImage:image];
        flickrNameController.view.autoresizingMask = UIViewAutoresizingNone;
        flickrNameController.delegate = self;
        
        [self.view addSubview:flickrNameController.view];
        [self.navigationItem.backBarButtonItem setEnabled:NO];   
        [self.navigationItem.rightBarButtonItem setEnabled:NO];
        
    }
    
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    //make sure this scroll view is the table and not a text view
    if ([scrollView isKindOfClass:[UITextView class]]) {
        return;
    }
    
    //check comment fields for first responder
    for (int row = 1; row < 6; row++) {
        if ([(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]] viewWithTag:row + 10] isFirstResponder]) {
            [(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]] viewWithTag:row + 10] resignFirstResponder];
            
            //set the tableview inset back to the original size
            [UIView beginAnimations:nil context:nil];
            [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
            [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)]; 
            [UIView commitAnimations];
            
            return;
        }
    }
    
    //check comment text view for first responder    
    if ([(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:3]] viewWithTag:11] isFirstResponder]) {
        [(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:3]] viewWithTag:11] resignFirstResponder];
        
        //set the tableview inset back to the original size
        [UIView beginAnimations:nil context:nil];
        [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
        [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)]; 
        [UIView commitAnimations];
        
        return;
    }
    
    if (_inEditMode) {
    //check art detail fields for first responder    
    for (int fieldTag = 1; fieldTag < 6; fieldTag++) {
        if ([(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]] viewWithTag:fieldTag] isFirstResponder]) {
            [(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]] viewWithTag:fieldTag] resignFirstResponder];
            
            //set the tableview inset back to the original size
            [UIView beginAnimations:nil context:nil];
            [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
            [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)]; 
            [UIView commitAnimations];
            
            return;
        }
    }
    }
    
    //check location detail fields for first responder    
    if (_inEditMode) {
    for (int fieldTag = 1; fieldTag < 3; fieldTag++) {
        if ([(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]] viewWithTag:fieldTag] isFirstResponder]) {
            [(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]] viewWithTag:fieldTag] resignFirstResponder];
            
            //set the tableview inset back to the original size
            [UIView beginAnimations:nil context:nil];
            [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
            [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)]; 
            [UIView commitAnimations];
            
            return;
        }
    }    
    }
    
    if (_inEditMode) {
    //check loc description text view for first responder    
    if ([(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:1]] viewWithTag:1] isFirstResponder]) {
        [(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:1]] viewWithTag:1] resignFirstResponder];
        
        //set the tableview inset back to the original size
        [UIView beginAnimations:nil context:nil];
        [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
        [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)]; 
        [UIView commitAnimations];
        
        return;
    }
    }
    
}


//- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {	
    
	switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0: 
                    //Header Cell (title, artist, category, year)    
                {
                    
                    if (_inEditMode) {
                        return 200;
                    }
                    else {
                        if (_art.artDescription.length > 0) {
                            
                            CGSize reqdSize = [_art.artDescription sizeWithFont:kDetailFont constrainedToSize:CGSizeMake(_detailView.frame.size.width - (2 * kHorizontalPadding), MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
                            float height = reqdSize.height;
                            
                            if (_art.commissionedBy && _art.commissionedBy.length > 0)
                                height += 20;
                            
                            height += (_art.event != nil) ? 90 : 75;
                            
                            return height;
                        }
                        else
                            return 100;
                    }
                    break;
                }
                case 1:
                {
                    return self.detailView.photosScrollView.frame.size.height + 20;
                    break;
                }
                default:
                    break;
            }
            
            break;
        }
        case 1:
        {
            switch (indexPath.row) {
                case 0: 
                    //Header Cell    
                {
                    return 22;
                    break;
                }
                case 1:
                {
                    if (_inEditMode) {
                        return 98;
                    }
                    else {
                        CGSize reqdSize = [_art.locationDescription sizeWithFont:kDetailFont constrainedToSize:CGSizeMake(_detailView.frame.size.width - (2 * kHorizontalPadding), MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
                        return reqdSize.height + 10;
                    }
                    break;
                }
                case 2:
                {
                    return self.detailView.mapView.frame.size.height + 30;
                    break;
                }
                default:
                    return 0;
                    break;
            }
            
            break;
        }
        case 2:
        {
            //comments
            switch (indexPath.row) {
                //comment header
                case 0:
                    return 25;
                    break;
                //comments
                default:
                {
                    //if this is the last row - "view all comments" row
                    if (indexPath.row == (_art.comments.count * 2) + 1) {
                        return 25;
                    }
                    else //normal comment row
                    {
                    Comment *thisComment = [[_art.comments allObjects] objectAtIndex:((indexPath.row - 1) / 2.0)];
                    if (indexPath.row % 2 != 0)  
                        return 18;
                    else {
                        CGSize reqdSize = [thisComment.text sizeWithFont:kDetailFont constrainedToSize:CGSizeMake(_detailView.frame.size.width - (2 * kHorizontalPadding), MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
                        return reqdSize.height + 10;
                    }
                    }
                                            
                    break;
                 }
            }
            
            break;
        }
        case 3:
        {
            switch (indexPath.row) {
                case 0: 
                    //Header Cell     
                {
                    return 40;
                    break;
                }
                case 1:
                case 2:
                case 3:
                {
                    return 30;
                    break;
                }
                case 4:
                {
                    return 74;
                    break;
                }
                case 5:
                {
                    return 35;
                    break;
                }
                default:
                    return 0;
                    break;
            }  
            
            break;
        }
        default:
            return 0;
            break;
    }
    
    return 0;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {	
    return nil;
}




#pragma mark - UITableViewDataSource


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (_art) ? 4 : 2;
}

//always return at least one row so we can display a NoData cell
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 2;
            break;
        case 1:
            return 3;
            break;            
        case 2:
            if ([_art.comments isKindOfClass:[NSSet class]] && _art.comments.count > 3 && _showAllComments)       //show all comments (> 3)
                return (2 + (_art.comments.count * 2));
            else if ([_art.comments isKindOfClass:[NSSet class]] && _art.comments.count > 3)                      //just show 3 & "view more"
                return 8;
            else if ([_art.comments isKindOfClass:[NSSet class]] && _art.comments.count > 0)                      //show all comments (< 3)
                return 1 + (_art.comments.count * 2);
            else                                                   //no comments
                return 1;
            break;
        case 3:
            if (_inEditMode)
                return 0;
            else
                return 6;
            break;
        default:
            return 0;
            break;
    }
}

//subclasses MUST override this method
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
    
    
    switch (indexPath.section) {
            //Art Info
        case 0:
        {
            switch (indexPath.row) {
                case 0: 
                    //Header Cell (title, artist, category, year)    
                {
                    
                    if (_inEditMode) //if the controller is in edit mode - display the input fields
                    {
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"HeaderCellEditMode"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HeaderCellEditMode"];
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            
                            UIImageView *bgImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DetailBackground.jpg"]];
                            [bgImageView setFrame:CGRectInset(cell.frame, 0, 0)];
                            cell.backgroundView = bgImageView;
                            
                            double yOffset = 0;
                            
                            //if this is an update - just show the title label
                            //else - add the title field
                            if (_art) {
                                //title Label
                                UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 
                                                                                                kHorizontalPadding, 
                                                                                                cell.frame.size.width - (3 * kHorizontalPadding), 
                                                                                                25)];
                                titleLabel.tag = 1;
                                titleLabel.font = kH1Font;
                                titleLabel.textColor = kFontColorDarkBrown;
                                titleLabel.backgroundColor = [UIColor clearColor];
                                [cell addSubview:titleLabel];
                                
                                //set the offset
                                yOffset = titleLabel.frame.size.height;
                                
                                [titleLabel release];
                            }
                            else {
                                //title field
                                _artNameField = [[UITextField alloc] initWithFrame:CGRectMake(kHorizontalPadding + 75, 
                                                                                                        kHorizontalPadding, 
                                                                                                        220, 
                                                                                                        25)];
                                [_artNameField setTag:1];
                                [_artNameField setFont:kDetailFont];
                                [_artNameField setTextColor:kBGdarkBrown];
                                [_artNameField setPlaceholder:@"Title"];
                                [_artNameField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
                                [_artNameField setLeftViewMode:UITextFieldViewModeAlways];
                                [_artNameField setLeftView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                                [_artNameField setRightViewMode:UITextFieldViewModeAlways];
                                [_artNameField setRightView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                                if ([Utilities is5OrHigher])
                                    [_artNameField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                                else 
                                    [_artNameField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                                
                                [cell addSubview:_artNameField];
                                
                                //set the offset
                                yOffset = _artNameField.frame.size.height;
                                
                                //title label
                                UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 0, 66, 16)];
                                [titleLabel setText:@"Title:"];
                                [titleLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];
                                [titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:12]];
                                [titleLabel setBackgroundColor:[UIColor clearColor]];
                                [titleLabel setTextColor:kFontColorDarkBrown];
                                [titleLabel setCenter:CGPointMake(round(titleLabel.center.x), round(_artNameField.center.y))];
                                [cell addSubview:titleLabel];
                                [titleLabel release];
                            }
                            
                            //artist field & label
                            _artistField = [[UITextField alloc] initWithFrame:CGRectMake(kHorizontalPadding + 75, 
                                                                                                     kHorizontalPadding, 
                                                                                                     220, 
                                                                                                     26)];
                            [_artistField setFrame:CGRectOffset(_artistField.frame, 0, yOffset + 4)];
                            _artistField.tag = 2;
                            [_artistField setFont:kDetailFont];
                            [_artistField setTextColor:kBGdarkBrown];
                            [_artistField setPlaceholder:@"Artist"];
                            [_artistField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
                            [_artistField setLeftViewMode:UITextFieldViewModeAlways];
                            [_artistField setLeftView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                            [_artistField setRightViewMode:UITextFieldViewModeAlways];
                            [_artistField setRightView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                            if ([Utilities is5OrHigher])
                                [_artistField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                            else 
                                [_artistField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                            
                            [cell addSubview:_artistField];
                            
                            //artist label
                            UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 0, 66, 16)];
                            [artistLabel setText:@"Artist:"];
                            [artistLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:12]];
                            [artistLabel setBackgroundColor:[UIColor clearColor]];
                            [artistLabel setTextColor:kFontColorDarkBrown];
                            [artistLabel setCenter:CGPointMake(roundf(artistLabel.center.x), roundf(_artistField.center.y))];
                            [cell addSubview:artistLabel];
                            [artistLabel release];
                            
                            //category field & label
                            _categoryField = [[UITextField alloc] initWithFrame:CGRectMake(_artistField.frame.origin.x, _artistField.frame.origin.y + _artistField.frame.size.height + 4, 110, _artistField.frame.size.height)];
                            _categoryField.tag = 3;
                            [_categoryField setFont:kDetailFont];
                            [_categoryField setTextColor:kBGdarkBrown];
                            [_categoryField setPlaceholder:@"Category"];
                            [_categoryField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
                            [_categoryField setLeftViewMode:UITextFieldViewModeAlways];
                            [_categoryField setLeftView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                            [_categoryField setRightViewMode:UITextFieldViewModeAlways];
                            [_categoryField setRightView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                            if ([Utilities is5OrHigher])
                                [_categoryField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                            else 
                                [_categoryField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                            
                            [cell addSubview:_categoryField];
                            
                            //category label
                            UILabel *catLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 0, 76, 16)];
                            [catLabel setText:@"Category:"];
                            [catLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:12]];
                            [catLabel setBackgroundColor:[UIColor clearColor]];
                            [catLabel setTextColor:kFontColorDarkBrown];
                            [catLabel setCenter:CGPointMake(roundf(catLabel.center.x), roundf(_categoryField.center.y))];
                            [cell addSubview:catLabel];
                            [catLabel release];
                            
                            
                            //year field & label
                            _yearField = [[UITextField alloc] initWithFrame:CGRectMake(_artistField.frame.origin.x + _artistField.frame.size.width - 50, _artistField.frame.origin.y + _artistField.frame.size.height + 4, 50, _artistField.frame.size.height)];
                            _yearField.tag = 4;
                            [_yearField setFont:kDetailFont];
                            [_yearField setTextColor:kBGdarkBrown];
                            [_yearField setPlaceholder:@"Year"];
                            [_yearField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
                            [_yearField setLeftViewMode:UITextFieldViewModeAlways];
                            [_yearField setLeftView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                            [_yearField setRightViewMode:UITextFieldViewModeAlways];
                            [_yearField setRightView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                            if ([Utilities is5OrHigher])
                                [_yearField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                            else 
                                [_yearField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                            [cell addSubview:_yearField];
                            
                            //year label
                            UILabel *yearLabel = [[UILabel alloc] initWithFrame:CGRectMake(_categoryField.frame.origin.x + _categoryField.frame.size.width + 15, 0, 40, 16)];
                            [yearLabel setText:@"Year:"];
                            [yearLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:12]];
                            [yearLabel setBackgroundColor:[UIColor clearColor]];
                            [yearLabel setTextColor:kFontColorDarkBrown];
                            [yearLabel setCenter:CGPointMake(roundf(yearLabel.center.x), roundf(_yearField.center.y))];
                            [cell addSubview:yearLabel];
                            [yearLabel release];
                            
                            //description field & label
                            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(catLabel.frame.origin.x, 0, 80, 16)];
                            [descLabel setText:@"Description:"];
                            [descLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:12]];
                            [descLabel setBackgroundColor:[UIColor clearColor]];
                            [descLabel setTextColor:kFontColorDarkBrown];
                            [descLabel setCenter:CGPointMake(roundf(descLabel.center.x), roundf(catLabel.center.y + (catLabel.center.y - artistLabel.center.y)))];
                            
                            UIImageView *textViewBackground = [[UIImageView alloc] initWithFrame:CGRectMake(kHorizontalPadding, descLabel.frame.origin.y + descLabel.frame.size.height + 4, 296, 70)];
                            
                            if ([Utilities is5OrHigher])
                                [textViewBackground setImage:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                            else 
                                [textViewBackground setImage:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                            
                            
                            
                            _artDescriptionView = [[UITextView alloc] initWithFrame:CGRectInset(textViewBackground.frame, 5, 5)];
                            _artDescriptionView.tag = 5;
                            [_artDescriptionView setFont:kDetailFont];
                            [_artDescriptionView setTextColor:kBGdarkBrown];
                            
                            [cell addSubview:descLabel];                            
                            [cell addSubview:textViewBackground];
                            [cell addSubview:_artDescriptionView];
                            [textViewBackground release];
                            [descLabel release];
                            
                        }
                        
                        //if this is an update - set title label text & other fields
                        if (_art) {
                            [(UILabel*)[cell viewWithTag:1] setText:_art.title];
                         
                            if (_categoryField.text.length == 0 && [_art categoriesString].length != 0)
                                _categoryField.text = [_art categoriesString];
                            
                            if (_artistField.text.length == 0 && _art.artist.length != 0)
                                _artistField.text = _art.artist;
                            
                            if (_yearField.text.length == 0 && _art.year != 0)
                                _yearField.text = [_art.year stringValue];
                            
                            if (_artDescriptionView.text.length == 0 && _art.artDescription != 0)
                                _artDescriptionView.text = _art.artDescription;
                        }
                        
                        
                        return cell;
                        
                    }
                    else {
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"HeaderCell"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HeaderCell"];
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            
                            UIImageView *bgImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DetailBackground.jpg"]];
                            [bgImageView setFrame:CGRectInset(cell.frame, 0, 0)];
                            cell.backgroundView = bgImageView;
                            
                            EGOImageView *eventIcon = [[EGOImageView alloc] init];
                            [eventIcon setTag:10];
                            [eventIcon setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin];
                            EGOImageView *commissionedIcon = [[EGOImageView alloc] init];
                            [commissionedIcon setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin];                            
                            [commissionedIcon setTag:11];
                            EGOImageView *popularIcon = [[EGOImageView alloc] init];
                            [popularIcon setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin];                            
                            [popularIcon setTag:12];
                            [cell addSubview:commissionedIcon];
                            [cell addSubview:eventIcon];
                            [cell addSubview:popularIcon];
                            [commissionedIcon release];
                            [eventIcon release];
                            
                            
                            //title Label
                            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 
                                                                                            kHorizontalPadding, 
                                                                                            roundf(cell.frame.size.width - (2 * kHorizontalPadding) - eventIcon.frame.origin.x), 
                                                                                            20)];
                            titleLabel.tag = 1;
                            titleLabel.font = kH1Font;
                            titleLabel.textColor = kFontColorDarkBrown;
                            titleLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:titleLabel];
                            [titleLabel release];
                            
                            
                            //artist label
                            UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, titleLabel.frame.origin.y + titleLabel.frame.size.height + 4, roundf(cell.frame.size.width - (2 * kHorizontalPadding)), 12)];
                            artistLabel.tag = 2;
                            artistLabel.textColor = kFontColorDarkBrown;
                            artistLabel.font = kDetailFont;
                            artistLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:artistLabel];
                            [artistLabel release];
                            
                            //year label
                            UILabel *yearLabel = [[UILabel alloc] initWithFrame:CGRectInset(artistLabel.frame, 0, 0)];
                            yearLabel.tag = 5;
                            yearLabel.textColor = kFontColorDarkBrown;
                            yearLabel.font = kBoldDetailFont;
                            yearLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:yearLabel];
                            [yearLabel release];
                            
                            //category label
                            UILabel *catLabel = [[UILabel alloc] initWithFrame:CGRectOffset(artistLabel.frame, 0, artistLabel.frame.size.height + 2)];
                            catLabel.tag = 3;
                            catLabel.textColor = kFontColorDarkBrown;
                            catLabel.font = kBoldDetailFont;
                            catLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:catLabel];
                            [catLabel release];
                            
                            //commisioned by label
                            UILabel *commissionedByLabel = [[UILabel alloc] initWithFrame:CGRectOffset(catLabel.frame, 0, catLabel.frame.size.height + 2)];
                            commissionedByLabel.tag = 7;
                            commissionedByLabel.textColor = kFontColorDarkBrown;
                            commissionedByLabel.font = kDetailFont;
                            commissionedByLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:commissionedByLabel];
                            [commissionedByLabel release];
                            
                            //event label
                            UILabel *eventLabel = [[UILabel alloc] initWithFrame:CGRectOffset(commissionedByLabel.frame, 0, commissionedByLabel.frame.size.height + 2)];
                            eventLabel.tag = 6;
                            eventLabel.textColor = kFontColorDarkBrown;
                            eventLabel.font = [UIFont fontWithName:@"Helvetica-Oblique" size:11];
                            eventLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:eventLabel];
                            [eventLabel release];
                            
                            //description label
                            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectOffset(eventLabel.frame, 0, eventLabel.frame.size.height + 4)];
                            descLabel.tag = 4;
                            descLabel.textColor = kFontColorDarkBrown;
                            descLabel.numberOfLines = 0;
                            descLabel.font = kDetailFont;
                            descLabel.backgroundColor = [UIColor clearColor];
                            [cell addSubview:descLabel];
                            [descLabel release];
                            
                        }
                        
                        
                        //set icons
                        EGOImageView *eIcon = (EGOImageView*)[cell viewWithTag:10];
                        EGOImageView *cIcon = (EGOImageView*)[cell viewWithTag:11];
                        EGOImageView *pIcon = (EGOImageView*)[cell viewWithTag:12];                        
                        
                        //check commission
                        if ([_art.commissioned boolValue]) {
                            cIcon.image = [UIImage imageNamed:@"commissionedIcon.png"];
                            cIcon.frame = CGRectMake(0, 0, cIcon.image.size.width, cIcon.image.size.height);
                        }
                        else {
                            cIcon.image = nil;
                            cIcon.frame = CGRectZero;
                        }
                        
                        //check popular
                        if ([_art.rank intValue] >= 0) {
                            pIcon.image = [UIImage imageNamed:@"popularIcon.png"];
                            pIcon.frame = CGRectMake(0, 0, pIcon.image.size.width, pIcon.image.size.height);
                        }
                        else {
                            pIcon.image = nil;
                            pIcon.frame = CGRectZero;
                        }
                        
                        //check event
                        //if (_art.event && [_art.event.name isEqualToString:@"5x5"]) {
                        if (_art.event) {
                            if (_art.event.iconURL.length > 0 && _art.event.iconURLSmall.length > 0) {
                                eIcon.imageURL = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"%@%@", kArtAroundURL, ([Utilities isRetinaDisplay]) ? _art.event.iconURL : _art.event.iconURLSmall]];
                                eIcon.frame = CGRectMake(0, 0, 30, 30);
                            }
                            else {
                                eIcon.frame = CGRectMake(0, 0, eIcon.image.size.width, eIcon.image.size.height);
                            }
                        }
                        else {
                            eIcon.image = nil;
                            eIcon.frame = CGRectZero;
                        }
                        
                        cIcon.frame = CGRectMake(cell.frame.size.width - kHorizontalPadding - cIcon.frame.size.width, kHorizontalPadding, cIcon.frame.size.width, cIcon.frame.size.height);
                        
                        eIcon.frame = CGRectMake(cIcon.frame.origin.x - 5 - eIcon.frame.size.width, kHorizontalPadding, eIcon.frame.size.width, eIcon.frame.size.height);
                        
                        pIcon.frame = CGRectMake(eIcon.frame.origin.x - 5 - pIcon.frame.size.width, kHorizontalPadding, pIcon.frame.size.width, pIcon.frame.size.height);
                        
                        //set the title label
                        UILabel *tLabel = (UILabel*)[cell viewWithTag:1];
                        [tLabel setText:_art.title];
                        tLabel.frame = CGRectMake(kHorizontalPadding, 
                                                  kHorizontalPadding, 
                                                  roundf(cell.frame.size.width - (2 * kHorizontalPadding) - (cell.frame.size.width - pIcon.frame.origin.x)), 
                                                  20);
                        
                        //set category label text
                        [(UILabel*)[cell viewWithTag:3] setText:[[_art categoriesString] uppercaseString]];
                        
                        //arrange the artist & year label                        
                        UILabel *aLabel = (UILabel*)[cell viewWithTag:2];
                        UILabel *yLabel = (UILabel*)[cell viewWithTag:5];                        
                        
                        if (_art.year != NULL && _art.year != nil && _art.year != 0) {
                            [yLabel setText:[_art.year stringValue]];
                        }
                        
                        if (_art.artist.length > 0 && _art.year != NULL && _art.year != nil && _art.year != 0) {
                            [aLabel setText:[NSString stringWithFormat:@"%@ - ", _art.artist, nil]];
                        }
                        else if (_art.artist.length > 0) {
                            [aLabel setText:_art.artist];
                        }
                        else {
                            [aLabel setText:@""];
                        }
                        
                        
                        double reqdWidth = [aLabel.text sizeWithFont:aLabel.font].width;
                        double maxWidth = roundf(cell.frame.size.width - (2 * kHorizontalPadding));
                        aLabel.frame = CGRectMake(aLabel.frame.origin.x, aLabel.frame.origin.y, roundf((reqdWidth > maxWidth) ? maxWidth : reqdWidth), aLabel.frame.size.height);
                        yLabel.frame = CGRectMake(aLabel.frame.origin.x + aLabel.frame.size.width, yLabel.frame.origin.y, [yLabel.text sizeWithFont:aLabel.font].width, yLabel.frame.size.height);
                        
                        //set the commissionedBy label and arrange
                        UILabel *cLabel = (UILabel*)[cell viewWithTag:7];
                        
                        if (_art.commissionedBy != nil) {
                            [cLabel setText:[NSString stringWithFormat:@"Commissioned by %@", _art.commissionedBy]];
                        }
                        else {
                            [cLabel setText:@""];
                        }
                        
                        CGSize cSize = [cLabel.text sizeWithFont:cLabel.font constrainedToSize:CGSizeMake(maxWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
                        [cLabel setFrame:CGRectMake(cLabel.frame.origin.x, cLabel.frame.origin.y, maxWidth, cSize.height)];
                        
                        //set the event label and arrange
                        UILabel *eLabel = (UILabel*)[cell viewWithTag:6];
                        
                        if (_art.event != nil) {
                            [eLabel setText:[NSString stringWithFormat:@"Part of the %@ event", _art.event.name]];
                        }
                        else {
                            [eLabel setText:@""];
                        }
                        
                        CGSize eventSize = [eLabel.text sizeWithFont:eLabel.font constrainedToSize:CGSizeMake(maxWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
                        [eLabel setFrame:CGRectMake(eLabel.frame.origin.x, cLabel.frame.origin.y + cLabel.frame.size.height + 4, maxWidth, eventSize.height)];
                        
                        //set the description label and arrange
                        UILabel *dLabel = (UILabel*)[cell viewWithTag:4];
                        [dLabel setText:_art.artDescription];
                        CGSize reqdSize = [dLabel.text sizeWithFont:dLabel.font constrainedToSize:CGSizeMake(maxWidth, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap];
                        [dLabel setFrame:CGRectMake(dLabel.frame.origin.x, eLabel.frame.origin.y + eLabel.frame.size.height + 4, maxWidth, roundf(reqdSize.height))];
                        
                        
                        return cell;
                    }
                    break;
                }
                case 1:
                    //Photo ScrollView
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"PhotosCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PhotosCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.contentView.backgroundColor = [UIColor clearColor];
                        
                        self.detailView.photosScrollView.frame = CGRectOffset(self.detailView.photosScrollView.frame, 0, 10);
                        [cell addSubview:self.detailView.photosScrollView];
                        
                    }
                    
                    return cell;
                    break;
                }
                default:
                    break;
            }
            
            break;
        }
            //Location Info
        case 1:
        {
            switch (indexPath.row) {
                case 0:
                    //location header
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"LocationTitleCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LocationTitleCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.contentView.backgroundColor = kBGlightBrown;
                        cell.textLabel.font = kH2Font;
                        cell.textLabel.backgroundColor = [UIColor clearColor];
                        cell.textLabel.textColor = kFontColorDarkBrown;
                    }
                    
                    cell.textLabel.text = @"Location";
                    
                    return cell;
                    break;
                }
                case 1:
                //locaiton desc cell
                {
                    
                    if (_inEditMode) {
                        
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"LocationDescriptionInputCell"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LocationDescriptionInputCell"];
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            cell.contentView.backgroundColor = kBGlightBrown;
                            
                            
                            //description field & label
                            UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 0, 80, 16)];
                            [descLabel setText:@"Description:"];
                            [descLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:12]];
                            [descLabel setBackgroundColor:[UIColor clearColor]];
                            [descLabel setTextColor:kFontColorDarkBrown];
                            
                            UIImageView *textViewBackground = [[UIImageView alloc] initWithFrame:CGRectMake(kHorizontalPadding, descLabel.frame.origin.y + descLabel.frame.size.height + 4, roundf(cell.frame.size.width - (2 * kHorizontalPadding)), 70)];
                            
                            if ([Utilities is5OrHigher])
                                [textViewBackground setImage:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                            else 
                                [textViewBackground setImage:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                            
                            _locationDescriptionView = [[UITextView alloc] initWithFrame:CGRectInset(textViewBackground.frame, 5, 5)];
                            _locationDescriptionView.tag = 1;
                            [_locationDescriptionView setDelegate:self];
                            [_locationDescriptionView setFont:kDetailFont];
                            [_locationDescriptionView setTextColor:kBGdarkBrown];
                            
                            [cell addSubview:descLabel];                            
                            [cell addSubview:textViewBackground];
                            [cell addSubview:_locationDescriptionView];
                            [textViewBackground release];
                            [descLabel release];
                        }
                        
                        //if this is an update - set field text
                        if (_art) {
                            
                            if (_locationDescriptionView.text.length == 0 && _art.locationDescription.length != 0)
                                _locationDescriptionView.text = _art.locationDescription;
                            
                        }
                        
                        return cell;
                        
                    }
                    else {
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"LocationDescriptionCell"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LocationDescriptionCell"];
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            cell.contentView.backgroundColor = kBGlightBrown;
                            cell.textLabel.numberOfLines = 0;
                            cell.textLabel.font = kDetailFont;
                            cell.textLabel.backgroundColor = [UIColor clearColor];
                            cell.textLabel.textColor = kFontColorDarkBrown;                        
                        }
                        
                        cell.textLabel.text = _art.locationDescription;
                        
                        return cell;
                    }
                    
                    break;
                }                    
                case 2:
                    //map cell
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"MapCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MapCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        
                        UIView *brownView = [[UIView alloc] initWithFrame:CGRectMake(0, 10, cell.frame.size.width, self.detailView.mapView.frame.size.height + 10)];
                        brownView.backgroundColor = kBGBrown;
                        [cell addSubview:brownView];
                        [brownView release];
                        
                        
                        self.detailView.mapView.frame = CGRectOffset(self.detailView.mapView.frame, 0, 15);
                        CGFloat components[] = { 1.0, 1.0, 1.0, 1.0 };
                        self.detailView.mapView.layer.borderColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), components);
                        self.detailView.mapView.layer.borderWidth = 8;
                        [cell addSubview:self.detailView.mapView];
                        
                    }
                    
                    return cell;
                    break;
                }
                    
                default:
                    return nil;
                    break;
            }
            
            break;
        }
        case 2:
        {
            //comments
            switch (indexPath.row) {
                case 0:
                    //comments title
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"CommentsTitleCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CommentsTitleCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.contentView.backgroundColor = kBGlightBrown;                        
                        cell.textLabel.font = kH2Font;
                        cell.textLabel.textColor = kFontColorDarkBrown;
                        cell.textLabel.backgroundColor = [UIColor clearColor];
                    }
                    
                    cell.textLabel.text = [NSString stringWithFormat:@"Comments (%i)", (_art.comments && [_art.comments isKindOfClass:[NSSet class]]) ? _art.comments.count : 0];
                    
                    return cell;
                    break;
                }
                    
                default:
                    //comments
                {
                    
                    //if this is the last row - "view all comments" row
                    if ((!_showAllComments && _art.comments.count > 3 && indexPath.row == 7) ||
                        (_showAllComments && indexPath.row == (_art.comments.count * 2) + 1)) {
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"ShowCommentsCell"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ShowCommentsCell"];
                            cell.selectionStyle = UITableViewCellSelectionStyleGray;
                            cell.contentView.backgroundColor = kBGlightBrown;
                            cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Oblique" size:11];
                            cell.textLabel.textColor = kFontColorDarkBrown;
                            [cell.textLabel setTextAlignment:UITextAlignmentRight];
                            [cell.textLabel setBackgroundColor:kBGlightBrown];
                        }
                        
                        [cell.textLabel setText:(_showAllComments) ? @"" : @"View all comments..."];
                        
                        if (_showAllComments)
                            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                        else
                            [cell setSelectionStyle:UITableViewCellSelectionStyleGray];
                        
                        return cell;
                    }
                    
                    
                    Comment *thisComment = [[[_art.comments allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                        return [[obj2 createdAt] compare:[obj1 createdAt]];
                    } ]objectAtIndex:((indexPath.row - 1) / 2.0)];
                    
                    if (indexPath.row % 2 != 0) //comment meta
                    {
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"CommentsMetaCell"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CommentsMetaCell"];
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            cell.contentView.backgroundColor = kBGlightBrown;
                            
                            //neighborhood label & value
                            UILabel *nLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorizontalPadding, 6, 0, 12)];
                            nLabel.font = kBoldDetailFont;
                            nLabel.tag = 1;
                            nLabel.backgroundColor = [UIColor clearColor];
                            nLabel.textColor = kFontColorDarkBrown;
                            [cell addSubview:nLabel];
                            
                            UILabel *uLabel = [[UILabel alloc] initWithFrame:CGRectOffset(nLabel.frame, nLabel.frame.size.width, 0)];
                            uLabel.font = kDetailFont;
                            uLabel.backgroundColor = [UIColor clearColor];                        
                            uLabel.tag = 2;
                            uLabel.textColor = kFontColorDarkBrown;
                            [cell addSubview:uLabel];
                            
                            //ward label & value
                            UILabel *cLabel = [[UILabel alloc] init];
                            cLabel.font = kBoldDetailFont;
                            cLabel.backgroundColor = [UIColor clearColor];                        
                            cLabel.tag = 3;
                            cLabel.frame = CGRectMake(cell.frame.size.width - kHorizontalPadding - 70, 6, 70, 12);
                            cLabel.textColor = kFontColorDarkBrown;
                            [cell addSubview:cLabel];
                            
                            [uLabel release];
                            [cLabel release];
                            [nLabel release];
                        }
                        
                        //name
                        UILabel *nLabel = (UILabel*)[cell viewWithTag:1];
                        nLabel.text = [NSString stringWithFormat:@"%@%@", thisComment.name, (thisComment.url.length > 0) ? @" | " : @"", nil];
                        double nWidth = roundf([nLabel.text sizeWithFont:nLabel.font].width);
                        double maxWidth = roundf(cell.frame.size.width - (2 * kHorizontalPadding) - 80);
                        nLabel.frame = CGRectMake(nLabel.frame.origin.x, nLabel.frame.origin.y, ((nLabel.frame.origin.x + nWidth) > maxWidth) ? maxWidth : nWidth, nLabel.frame.size.height);
                        
                        //url
                        UILabel *uLabel = (UILabel*)[cell viewWithTag:2];
                        uLabel.text = thisComment.url;
                        double uWidth = roundf([uLabel.text sizeWithFont:uLabel.font].width + uLabel.frame.size.width);
                        double maxwWidth = roundf(cell.frame.size.width - (2 * kHorizontalPadding) - 75 - nLabel.frame.size.width);
                        uLabel.frame = CGRectMake(nLabel.frame.origin.x + nLabel.frame.size.width + 1, uLabel.frame.origin.y, (uWidth > maxwWidth) ? maxwWidth : (uWidth - uLabel.frame.size.width), uLabel.frame.size.height);

                        //created date
                        UILabel *cLabel = (UILabel*)[cell viewWithTag:3];                    
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"MMM dd, yyyy"];
                        cLabel.text = [dateFormatter stringFromDate:thisComment.createdAt];
                        
                        
                        return cell;
                    }
                    else //comment body
                    {
                        UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"CommentsDescriptionCell"];
                        
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CommentsDescriptionCell"];
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            cell.contentView.backgroundColor = kBGlightBrown;
                            cell.textLabel.numberOfLines = 0;
                            cell.textLabel.font = kDetailFont;
                            cell.textLabel.textColor = kFontColorDarkBrown;
                            cell.textLabel.backgroundColor = kBGlightBrown;
                        }
                        
                        cell.textLabel.text = thisComment.text;
                        
                        return cell;
                    }
                    break;
                }
            }
            break;
        }
        case 3:
        {
            //Add Comment
            switch (indexPath.row) {
                case 0:
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"LeaveCommentTitleCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LeaveCommentTitleCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.font = kH2Font;
                        cell.textLabel.textColor = kBGlightBrown;
                        cell.textLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
                        cell.contentView.backgroundColor = kBGBrown;
                        cell.textLabel.backgroundColor = [UIColor clearColor];            
                        
                        UIView *darkBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.frame.size.width, 10)];
                        [darkBox setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth];
                        [darkBox setBackgroundColor:kBGdarkBrown];
                        [cell addSubview:darkBox];
                        [darkBox release];
                        
                    }
                    
                    cell.textLabel.text = @"Leave a Comment";
                    
                    return cell;
                    break;
                }
                case 1:
                case 2:
                case 3:
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"CommentInputCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CommentInputCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.font = kBoldItalicDetailFont;
                        cell.textLabel.textColor = [UIColor whiteColor];
                        cell.textLabel.backgroundColor = [UIColor clearColor];
                        cell.contentView.backgroundColor = kBGBrown;                        
                        
                        //setup input textbox
                        UITextField *inputField = [[UITextField alloc] initWithFrame:CGRectMake(cell.frame.size.width - kHorizontalPadding - 250, 3, 250, 26)];
                        inputField.tag = indexPath.row + 10;
                        inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;             
                        inputField.delegate = self;
                        inputField.returnKeyType = UIReturnKeyNext;
                        [inputField setFont:kDetailFont];
                        [inputField setTextColor:kBGdarkBrown];
                        [inputField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
                        [inputField setLeftViewMode:UITextFieldViewModeAlways];
                        [inputField setLeftView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                        [inputField setRightViewMode:UITextFieldViewModeAlways];
                        [inputField setRightView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)]];
                        if ([Utilities is5OrHigher])
                            [inputField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                        else 
                            [inputField setBackground:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                        
                        [cell addSubview:inputField];
                        
                        [inputField release];
                        
                    }
                    
                    //setup the label string
                    NSString *labelString = @"";
                    NSString *placeholderString = @"";
                    
                    //set the string based on the row
                    switch (indexPath.row - 1) {
                        case 0:
                            labelString = @"name";
                            placeholderString = @"name";
                            break;
                        case 1:
                            labelString = @"email";
                            placeholderString = @"email";
                            break;
                        case 2:
                            labelString = @"url";
                            placeholderString = @"url";
                            break;
                        default:
                            break;
                    }
                    
                    cell.textLabel.text = labelString;
                    [(UITextField*)[cell viewWithTag:indexPath.row + 10] setPlaceholder:placeholderString];
                    
                    return cell;
                    break;
                }
                case 4:
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"CommentTextInputCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CommentTextInputCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.contentView.backgroundColor = kBGBrown;                        
                        cell.textLabel.backgroundColor = [UIColor clearColor];
                        

                        //setup text view bg
                        UIImageView *textViewBackground = [[UIImageView alloc] initWithFrame:CGRectInset(cell.frame, kHorizontalPadding, 3)];
                        [textViewBackground setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
                        
                        if ([Utilities is5OrHigher])
                            [textViewBackground setImage:[[UIImage imageNamed:@"TextFieldBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)]];
                        else 
                            [textViewBackground setImage:[[UIImage imageNamed:@"TextFieldBackground.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:12]];
                        
                        //setup input textbox
                        UITextView *inputField = [[UITextView alloc] initWithFrame:CGRectInset(textViewBackground.frame, 6, 6)];
                        inputField.tag = 11;
                        inputField.returnKeyType = UIReturnKeyDefault;                        
                        inputField.delegate = self;
                        inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                        

                        [cell addSubview:textViewBackground];
                        [cell addSubview:inputField];
                        
                        [textViewBackground release];
                        [inputField release];
                        
                    }
                    
                    return cell;
                    break;
                }
                case 5:
                {
                    UITableViewCell *cell = [self.detailView.tableView dequeueReusableCellWithIdentifier:@"CommentSubmitCell"];
                    
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CommentSubmitCell"];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.contentView.backgroundColor = kBGBrown;
                        cell.backgroundColor = kBGBrown;
                        cell.accessoryView.backgroundColor = kBGBrown;
                        
                        //setup submit button
                        UIImage *btnImg = ([Utilities is5OrHigher]) ? [[UIImage imageNamed:@"SubmitButton.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(20, 20, 20, 20)] : [[UIImage imageNamed:@"SubmitButton.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:20];
                        UIButton *submitButton = [[UIButton alloc] initWithFrame:CGRectInset(cell.frame, 120, 6)];
                        [submitButton setTitle:@"Submit" forState:UIControlStateNormal];
                        [submitButton setTitleColor:[UIColor colorWithRed:(196.0/255.0) green:(199.0/255.0) blue:(47.0/255.0) alpha:1] forState:UIControlStateNormal];
                        [submitButton.titleLabel setFont:[UIFont fontWithName:@"Verdana-Bold" size:12.0]];
                        [submitButton setBackgroundColor:kBGBrown];
                        [submitButton setBackgroundImage:btnImg forState:UIControlStateNormal];
                        [submitButton addTarget:self action:@selector(submitCommentButtonTapped) forControlEvents:UIControlEventTouchUpInside];
                        [submitButton setCenter:CGPointMake(roundf(cell.frame.size.width - (submitButton.frame.size.width / 2.0) - 15), cell.center.y)];
                        [submitButton setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
                        [submitButton setContentMode:UIViewContentModeScaleAspectFit];
                        [cell addSubview:submitButton];
                        [submitButton release];
                        
                    }
                    
                    return cell;
                    break;
                }
                    
                default:
                    break; 
            }
            break;
        }
        default:
            return nil;
            break;
    }
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"rando"];
    
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        if ((!_showAllComments && _art.comments.count > 3 && indexPath.row == 7) ||
            (_showAllComments && indexPath.row == (_art.comments.count * 2) + 1)) {
            //only selectable cell is the view more cell
            _showAllComments = YES;
            [self.detailView.tableView reloadData];
        }
    }
}


#pragma mark - UITextFieldDelegate Methods
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {return YES;}

- (void)textFieldDidBeginEditing:(UITextField *)textField {}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
    //comment fields
    if (textField.tag > 10) {
        //if the comment dictionary doesn't exist then create it
        if (!_newCommentDictionary)
            _newCommentDictionary = [[NSMutableDictionary alloc] init];
        
        switch (textField.tag - 11) {
            case 0:
            {
                [_newCommentDictionary setValue:textField.text forKey:@"name"];
                break;
            }
            case 1:
            {
                [_newCommentDictionary setValue:textField.text forKey:@"email"];
                break;
            }
            case 2:
            {
                [_newCommentDictionary setValue:textField.text forKey:@"url"];
                break;
            }
            default:
                break;
        }
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField 
{
    
    //set the tableview inset so the keyboard doesn't cover the table
    [UIView beginAnimations:nil context:nil];
    [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, 220.0, 0.0)];
    [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, 220.0, 0.0)];    
    [self.detailView.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(textField.tag > 10) ? 1 : 0 inSection:(textField.tag > 10) ? 3 : 1] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    [UIView commitAnimations];
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {return YES;}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {return YES;}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    
    //if this is a comment field
    if (textField.tag > 10) {
        
        //set focuse on the next text field
        //if it's the 3rd text field set focus on the text view
        if (textField.tag < 13) {
            [(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:textField.tag - 9 inSection:3]] viewWithTag:textField.tag + 1] becomeFirstResponder];
        }
        else {
            [(UITextView*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:3]] viewWithTag:11] becomeFirstResponder];
        }
        
    }
    
    return YES;
}

#pragma mark - UITextViewDelegate Methods

- (void) textViewDidBeginEditing:(UITextView *)textView {}

- (void) textViewDidEndEditing:(UITextView *)textView 
{
    
    //if the comment dictionary doesn't exist then create it
    if (!_newCommentDictionary)
        _newCommentDictionary = [[NSMutableDictionary alloc] init];
    
    
    //set the comment text
    [_newCommentDictionary setValue:textView.text forKey:@"text"];
    
    
    //figure out if user is in a different text field
//    BOOL userIsStillInputting = NO;
//    
//    for (int row = 1; row < 4; row++) {
//        if ([(UITextField*)[[self.detailView.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:3]] viewWithTag:row] isFirstResponder])
//            userIsStillInputting = YES;
//    }
//    
//    if (!userIsStillInputting) {
//        //only if the user is done inputting set the tableview inset back to the original size
//        [UIView beginAnimations:nil context:nil];
//        [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];
//        [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, _kSubmitButtonBarHeight, 0.0)];    
//        [UIView commitAnimations];
//    }
    
}

- (BOOL) textViewShouldBeginEditing:(UITextView *)textView 
{
    
    //set the tableview inset so the keyboard doesn't cover the table
    [UIView beginAnimations:nil context:nil];
    [self.detailView.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, 220.0, 0.0)];
    [self.detailView.tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0.0, 0.0, 220.0, 0.0)];    
    [UIView commitAnimations];
    
    //if the tag is > 10 it's a comment view
    if (textView.tag > 10) {
        [self.detailView.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:3] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    else {
        [self.detailView.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    
    return YES;
}

- (BOOL) textViewShouldEndEditing:(UITextView *)textView {return YES;}

- (BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {return  YES;}

- (void) textViewDidChangeSelection:(UITextView *)textView {}

- (void) textViewDidChange:(UITextView *)textView {}


#pragma mark - FlagViewControllerDelegate
//submit flag
- (void)flagViewControllerPressedSubmit:(id)controller
{
    [[AAAPIManager instance] submitFlagForSlug:_art.slug withText:[[(FlagViewController*)controller flagDescriptionTextview] text] target:self callback:@selector(flagSubmissionCompleted) failCallback:@selector(flagSubmissionFailed)];
    
}

//dismiss flag controller
- (void) flagViewControllerPressedCancel
{
    [[self.view.subviews objectAtIndex:(self.view.subviews.count - 1)] removeFromSuperview];
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
}

//successful submission
- (void) flagSubmissionCompleted
{
    [[self.view.subviews objectAtIndex:(self.view.subviews.count - 1)] removeFromSuperview];
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    [self.navigationItem.rightBarButtonItem setEnabled:YES];    
}

//unsuccessful submission
- (void) flagSubmissionFailed
{
    [[self.view.subviews objectAtIndex:(self.view.subviews.count - 1)] removeFromSuperview];  
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    [self.navigationItem.rightBarButtonItem setEnabled:YES];    
}

#pragma mark - FlickrNameViewControllerDelegate
//submit flag
- (void)flickrNameViewControllerPressedSubmit:(id)controller
{
    [Utilities instance].photoAttributionText = [[NSString alloc] initWithString:[[(FlickrNameViewController*)controller flickrHandleField] text]];
    [Utilities instance].photoAttributionURL = [[NSString alloc] initWithString:[[(FlickrNameViewController*)controller attributionURLField] text]];
    [self userAddedImage:[(FlickrNameViewController*)controller image]];
    
    
    
    [[controller view] removeFromSuperview];
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    
    if (!_inEditMode)
        [self.navigationItem.rightBarButtonItem setEnabled:YES];
    
    //[[AAAPIManager instance] submitFlagForSlug:_art.slug withText:[[(FlickrNameViewController*)controller flickrHandleField] text] target:self callback:@selector(flickrNameSubmissionCompleted) failCallback:@selector(flickrNameSubmissionFailed)];
    
    
    
}

//dismiss flag controller
- (void) flickrNameViewControllerPressedCancel:(id)controller
{

    [self userAddedImage:[(FlickrNameViewController*)controller image]];
    
    //[[self.view.subviews objectAtIndex:(self.view.subviews.count - 1)] removeFromSuperview];
    [[(FlickrNameViewController*)controller view] removeFromSuperview];
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    
    if (!_inEditMode)
        [self.navigationItem.rightBarButtonItem setEnabled:YES];
}

//successful submission
- (void) flickrNameSubmissionCompleted
{
    [[self.view.subviews objectAtIndex:(self.view.subviews.count - 1)] removeFromSuperview];
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    
    if (!_inEditMode)
        [self.navigationItem.rightBarButtonItem setEnabled:YES];    
}

//unsuccessful submission
- (void) flickrNameSubmissionFailed
{
    [[self.view.subviews objectAtIndex:(self.view.subviews.count - 1)] removeFromSuperview];  
    [self.navigationItem.backBarButtonItem setEnabled:YES];
    
    if (!_inEditMode)
        [self.navigationItem.rightBarButtonItem setEnabled:YES];    
}

#pragma mark - PhotoImageViewDelegate
- (void) attributionButtonPressed:(id)sender withTitle:(NSString*)title andURL:(NSURL*)url
{
    //create request
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    
    //create webview
    UIWebView *webView = [[UIWebView alloc] init];
    [webView loadRequest:request];
    
    //create view controller
    UIViewController *containerViewController = [[UIViewController alloc] init];
    [containerViewController setView:webView];
    
    /*
    //create the navcontroller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:containerViewController];
    
    //create close button and add to nav bar
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStyleDone target:self action:@selector(closeModalViewController:)];
    [containerViewController.navigationItem setLeftBarButtonItem:closeButton];
    
    
    //present nav controller
    [self presentModalViewController:navController animated:YES];
    */
    [self.navigationController pushViewController:containerViewController animated:YES];
    
}

@end
