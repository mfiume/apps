//
//  ChooseAccountViewController.m
//  Purple
//
//  Created by Marc Fiume on 2013-09-30.
//  Copyright (c) 2013 Marc Fiume. All rights reserved.
//

#import "ChooseAccountViewController.h"
#import "Colors.h"
#import "ViewUtil.h"
#import "AccountAdapter.h"
#import "InternalCode.h"
#import "NetUtils.h"
#import "CryptoUtils.h"
#import "SessionController.h"
#import "Checkout.h"
#import "ProcessPaymentViewController.h"

@interface ChooseAccountViewController ()

@end

@implementation ChooseAccountViewController

@synthesize container;

static int INDEX_OF_QUICKCHECKOUT_SECTION = 1;
static int INDEX_OF_ONETIMECHECKOUT_SECTION = 2;
static int INDEX_OF_ACCOUNT_SECTION = 0;

static int TAG_OF_PASSWORD_ALERT = 0;
static int TAG_OF_QUICKPASSWORD_ALERT = 1;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self initTable];
}

-(void) initTable {
    tableView = [[container subviews] objectAtIndex:0];
    [tableView setBackgroundColor:[UIColor clearColor]];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self refreshTable];
}

-(void) refreshTable {
    [tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == INDEX_OF_ACCOUNT_SECTION) {
        return [ViewUtil getMembershipName];
    } else if (section == INDEX_OF_ONETIMECHECKOUT_SECTION) {
        return @"No account";
    } else {
        return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"AccountCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if (indexPath.row % 2 == 1) {
        [cell.contentView setBackgroundColor:[Colors getTertiaryBackgroundColor]];
    }
    
    [ViewUtil addLineBorder:cell.contentView];
    [ViewUtil addDisclosureIndicatorToTableCell:cell];
    
    // account
    if (indexPath.section == INDEX_OF_ACCOUNT_SECTION) {
        [cell.textLabel setText:@"Regular checkout"];
    } else if (indexPath.section == INDEX_OF_ONETIMECHECKOUT_SECTION) {
        [cell.textLabel setText:@"One time checkout"];
    } else {
        [cell.textLabel setText:@"Fast checkout"];
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    // one time checkout
    if (indexPath.section == INDEX_OF_ONETIMECHECKOUT_SECTION) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"OneTimeAddCardViewController"];
        [self.navigationController pushViewController:vc animated:YES];
    
    // account
    } else if (indexPath.section == INDEX_OF_ACCOUNT_SECTION) {
        [tv deselectRowAtIndexPath:indexPath animated:YES];
        UIAlertView * accountAlert = [[UIAlertView alloc] initWithTitle:[ViewUtil getMembershipName] message:@"enter your credentials" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK",nil];
        [accountAlert setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
        [[accountAlert textFieldAtIndex:0] setText:@"marcfiume@gmail.com"];
        accountAlert.tag = TAG_OF_PASSWORD_ALERT;
        [accountAlert show];
        [[accountAlert textFieldAtIndex:1] becomeFirstResponder];
    } else {
        [tv deselectRowAtIndexPath:indexPath animated:YES];
        UIAlertView * accountAlert = [[UIAlertView alloc] initWithTitle:[ViewUtil getMembershipName] message:@"enter your credentials" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK",nil];
        [accountAlert setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
        [[accountAlert textFieldAtIndex:0] setText:@"marcfiume@gmail.com"];
        accountAlert.tag = TAG_OF_QUICKPASSWORD_ALERT;
        [accountAlert show];
        [[accountAlert textFieldAtIndex:1] becomeFirstResponder];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return 1;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    int alertTag = [alertView tag];
    if(alertTag == TAG_OF_PASSWORD_ALERT)
    {
        if (buttonIndex == 1) {
            NSString *username = [alertView textFieldAtIndex:0].text;
            NSString *password = [alertView textFieldAtIndex:1].text;
            
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Logging in" message:@"Please wait..." delegate:self cancelButtonTitle:nil otherButtonTitles: nil];
            [alert show];
            
            // create a session
            [AccountAdapter createSessionWithEmail:username Password:[CryptoUtils md5:password] Handler:
             ^(NSURLResponse *response, NSData *data, NSError *error) {
                 
                 [alert dismissWithClickedButtonIndex:0 animated:YES];
                 
                 // session successful
                 if ([NetUtils wasRequestSuccessful:response]) {

                     NSString* session = [NetUtils getJSONValueForKey:kKEY_SESSION FromData:data];
                     [[SessionController getInstance] setSession:session];
                     [[SessionController getInstance] setUsername:username];
                     
                     // retrieve user information
                     [AccountAdapter getUserForSession:session Handler:
                      ^(NSURLResponse *response, NSData *data, NSError *error) {
                          
                          // user info successful
                          if ([NetUtils wasRequestSuccessful:response]) {

                              NSString* stripeCustomer = [NetUtils getJSONValueForKey:kKEY_STRIPECUSTOMER FromData:data];
                              [[SessionController getInstance] setStripeCustomer:stripeCustomer];

                              UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                              UIViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"ChoosePaymentViewController"];

                              [self.navigationController pushViewController:vc animated:YES];

                          // user info failed
                          } else {
                              
                              int internalCode = [NetUtils getInternalErrorCodeFromData:data];
                              [NetUtils showErrorMessageFromCode:internalCode];
                          }
                      }];

                // session failed
                 } else {
                     int internalCode = [NetUtils getInternalErrorCodeFromData:data];
                     [NetUtils showErrorMessageFromCode:internalCode];
                 }
             }];
        }
    } else if(alertTag == TAG_OF_QUICKPASSWORD_ALERT) {
        if (buttonIndex == 1) {
            NSString *username = [alertView textFieldAtIndex:0].text;
            NSString *password = [alertView textFieldAtIndex:1].text;
            
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Logging in" message:@"Please wait..." delegate:self cancelButtonTitle:nil otherButtonTitles: nil];
            [alert show];
            
            // create a session
            [AccountAdapter createSessionWithEmail:username Password:[CryptoUtils md5:password] Handler:
             ^(NSURLResponse *response, NSData *data, NSError *error) {
                 
                 [alert dismissWithClickedButtonIndex:0 animated:YES];
                 
                 // session successful
                 if ([NetUtils wasRequestSuccessful:response]) {
                     
                     NSString* session = [NetUtils getJSONValueForKey:kKEY_SESSION FromData:data];
                     [[SessionController getInstance] setSession:session];
                     [[SessionController getInstance] setUsername:username];
                     
                     // retrieve user information
                     [AccountAdapter getUserForSession:session Handler:
                      ^(NSURLResponse *response, NSData *data, NSError *error) {
                          
                          // user info successful
                          if ([NetUtils wasRequestSuccessful:response]) {
                              
                              NSString* stripeCustomer = [NetUtils getJSONValueForKey:kKEY_STRIPECUSTOMER FromData:data];
                              [[SessionController getInstance] setStripeCustomer:stripeCustomer];
                              
                              UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                              ProcessPaymentViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"ProcessPaymentViewController"];
                              
                              [self.navigationController pushViewController:vc animated:YES];
                              
                              [vc completeCheckout:[Checkout getCurrentCheckout]];
                              
                              // user info failed
                          } else {
                              
                              int internalCode = [NetUtils getInternalErrorCodeFromData:data];
                              [NetUtils showErrorMessageFromCode:internalCode];
                          }
                      }];
                     
                     // session failed
                 } else {
                     int internalCode = [NetUtils getInternalErrorCodeFromData:data];
                     [NetUtils showErrorMessageFromCode:internalCode];
                 }
             }];
        }
    }
}


@end
