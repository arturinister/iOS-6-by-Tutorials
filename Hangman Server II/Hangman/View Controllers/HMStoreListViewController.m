//
//  HMStoreListViewController.m
//  Hangman
//
//  Created by Ray Wenderlich on 7/12/12.
//  Copyright (c) 2012 Ray Wenderlich. All rights reserved.
//

#import <StoreKit/StoreKit.h>
#import "HangmanIAPHelper.h"
#import "HMStoreDetailViewController.h"
#import "HMStoreListViewController.h"
#import "HMStoreListViewCell.h"
#import "IAPProduct.h"
#import "IAPProductInfo.h"
#import "IAPProductPurchase.h"
#import "MBProgressHUD.h"
#import "UIImageView+AFNetworking.h"

@interface HMStoreListViewController () <SKStoreProductViewControllerDelegate, UIAlertViewDelegate>

@property (nonatomic, strong)	NSArray		*products;

@end

@implementation HMStoreListViewController
{
	BOOL					_observing;
	NSNumberFormatter		*_priceFormatter;
}

#pragma mark - Action & Selector Methods

- (void)doneTapped:(id)sender
{
}

- (void)reload
{
	self.products				= nil;
	[self.tableView reloadData];
	[[HangmanIAPHelper sharedInstance] requestProductsWithCompletionHandler:^(BOOL success, NSArray *products)
	{
		if (success)
			self.products		= products, [self.tableView reloadData];
		
		[self.refreshControl endRefreshing];
	}];
}

- (void)restoreTapped:(id)sender
{
	[[[UIAlertView alloc] initWithTitle:@"Restore Content"
								message:@"Would you like to restore any previous purchases?"
							   delegate:self
					  cancelButtonTitle:@"Cancel"
					  otherButtonTitles:@"Yes", nil] show];
}

#pragma mark - Music Store

- (void)showMusicStore
{
	MBProgressHUD *hud					= [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	hud.labelText						= @"Loading...";
	
	SKStoreProductViewController *viewController	= [[SKStoreProductViewController alloc] init];
	viewController.delegate				= self;
	
	NSDictionary *parameters			= @{SKStoreProductParameterITunesItemIdentifier: @286201200};
	[viewController loadProductWithParameters:parameters completionBlock:^(BOOL result, NSError *error)
	{
		[MBProgressHUD hideHUDForView:self.view animated:YES];
		
		if (result)
			[self presentViewController:viewController animated:YES completion:nil];
		else
			NSLog(@"Failed to load products.");
	}];
}

#pragma mark - SKStoreProductViewControllerDelegate Methods

/**
 *	called hwen the user dismissed the store screen
 *
 *	@param	viewController				store view controller whose interface was dismissed by the user
 */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
	NSLog(@"User finished shopping.");
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"PushDetail"])
	{
		HMStoreDetailViewController *detailViewController;
		detailViewController			= (HMStoreDetailViewController *)segue.destinationViewController;
		NSIndexPath *indexPath			= sender;
		IAPProduct *product				= self.products[indexPath.row];
		detailViewController.product	= product;
	}
}

#pragma mark - UIAlertViewDelegate Methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == alertView.firstOtherButtonIndex)
		[[HangmanIAPHelper sharedInstance] restoreCompletedTransactions];
}

#pragma mark - Setter & Getter Methods

- (void)setProducts:(NSArray *)products
{
	[self removeObservers];
	_products						= products;
	[self addObservers];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
																				 style:UIBarButtonItemStyleBordered
																				target:self
																			action:@selector(doneTapped:)];
	
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Restore"
																			  style:UIBarButtonItemStyleBordered
																			 target:self
																			 action:@selector(restoreTapped:)];
	
    _priceFormatter			= [[NSNumberFormatter alloc] init];
	[_priceFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[_priceFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	
	self.refreshControl		= [[UIRefreshControl alloc] init];
	[self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
	[self reload];
	[self.refreshControl beginRefreshing];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self addObservers];
	[self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self removeObservers];
}

#pragma mark - Key-Value Observation Methods

- (void)addObservers
{
	if (_observing || !self.products)	return;
	_observing						= TRUE;
	
	for (IAPProduct *product in self.products)
	{
		[product addObserver:self forKeyPath:@"purchaseInProgress" options:kNilOptions context:nil];
		[product addObserver:self forKeyPath:@"purchase" options:kNilOptions context:nil];
	}
}

- (void)removeObservers
{
	if (!_observing)				return;
	
	_observing						= FALSE;
	
	for (IAPProduct *product in self.products)
	{
		[product removeObserver:self forKeyPath:@"purchaseInProgress" context:nil];
		[product removeObserver:self forKeyPath:@"purchase" context:nil];
	}
}

#pragma mark - NSKeyValueObserving Methods

/**
 *	receive this messsage message when the value at the specified key path relative to the given object has changed
 *
 *	@param	keyPath					key path, relative to object, to the value that has changed
 *	@param	object					source object of the key path
 *	@param	change					dictionary that describing changes made to the value of the property at the key path
 *	@param	context					value provided when receiver registered to receive key-value observation notifications
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	IAPProduct *product				= (IAPProduct *)object;
	int row							= [self.products indexOfObject:product];
	NSIndexPath *indexPath			= [NSIndexPath indexPathForRow:row inSection:0];
	[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.products.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier		= @"Cell";
    HMStoreListViewCell *cell			= [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	
	if (indexPath.row < self.products.count)
	{
		IAPProduct *product					= self.products[indexPath.row];
		
		cell.titleLabel.text				= product.skProduct.localizedTitle;
		cell.descriptionLabel.text			= product.skProduct.localizedDescription;
		[_priceFormatter setLocale:product.skProduct.priceLocale];
		
		if (!product.purchase.consumable && product.purchase)
			cell.priceLabel.text			= @"Installed";
		else
			cell.priceLabel.text			= [_priceFormatter stringFromNumber:product.skProduct.price];
		
		[cell.iconImageView setImageWithURL:[NSURL URLWithString:product.info.icon] placeholderImage:[UIImage imageNamed:@"icon_placeholder.png"]];
	}
	else
	{
		cell.iconImageView.image			= [UIImage imageNamed:@"icon_music.png"];
		cell.titleLabel.text				= @"Game Music";
		cell.descriptionLabel.text			= @"Get some music for the game!";
		cell.priceLabel.text				= @"Various";
		cell.descriptionLabel.hidden		= NO;
		cell.progressView.hidden			= YES;
	}
	
    return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row < self.products.count)
		[self performSegueWithIdentifier:@"PushDetail" sender:indexPath];
	else
		[self performSegueWithIdentifier:@"PushMusic" sender:indexPath];
}

@end

































































