// Copyright 2018 David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SettingsViewController.h"

#import "LocalCachingClient.h"
#import "LoginViewController.h"
#import "Settings.h"
#import "TKMFontsViewController.h"
#import "Tables/TKMSwitchModelItem.h"
#import "Tables/TKMTableModel.h"
#import "proto/Wanikani+Convenience.h"

#import <UserNotifications/UserNotifications.h>

typedef void (^NotificationPermissionHandler)(BOOL granted);

@interface SettingsViewController ()
@end

@implementation SettingsViewController {
  TKMServices *_services;
  TKMTableModel *_model;
  NSIndexPath *_groupMeaningReadingIndexPath;

  NotificationPermissionHandler _notificationHandler;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(applicationDidBecomeActive:)
             name:UIApplicationDidBecomeActiveNotification
           object:nil];
}

- (void)rerender {
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];

  [model addSection:@"Notifications"];
  [model addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                     title:@"Notify for all available reviews"
                                                  subtitle:nil
                                                        on:Settings.notificationsAllReviews
                                                    target:self
                                                    action:@selector(allReviewsSwitchChanged:)]];
  [model addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                     title:@"Badge the app icon"
                                                  subtitle:nil
                                                        on:Settings.notificationsBadging
                                                    target:self
                                                    action:@selector(badgingSwitchChanged:)]];

  [model addSection:@"Lessons"];
  [model
      addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                  title:@"Prioritize current level"
                                               subtitle:@"Teach items from the current level first"
                                                     on:Settings.prioritizeCurrentLevel
                                                 target:self
                                                 action:@selector(prioritizeCurrentLevelChanged:)]];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Lesson order"
                                              subtitle:self.lessonOrderValueText
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapLessonOrder:)]];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Lesson batch size"
                                              subtitle:self.lessonBatchSizeText
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapLessonBatchSize:)]];

  [model addSection:@"Reviews"];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Review order"
                                              subtitle:self.reviewOrderValueText
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapReviewOrder:)]];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleSubtitle
                             title:@"Back-to-back"
                          subtitle:@"Group Meaning and Reading together"
                                on:Settings.groupMeaningReading
                            target:self
                            action:@selector(groupMeaningReadingSwitchChanged:)]];
  _groupMeaningReadingIndexPath = [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Back-to-back order"
                                              subtitle:self.taskOrderValueText
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapTaskOrder:)]
       hidden:!Settings.groupMeaningReading];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Reveal answer automatically"
                          subtitle:nil
                                on:Settings.showAnswerImmediately
                            target:self
                            action:@selector(showAnswerImmediatelySwitchChanged:)]];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                 title:@"Fonts"
                                              subtitle:nil
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapFonts:)]];
  [model addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                     title:@"Allow cheating"
                                                  subtitle:@"Ignore Typos and Add Synonym"
                                                        on:Settings.enableCheats
                                                    target:self
                                                    action:@selector(enableCheatsSwitchChanged:)]];
  [model
      addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                  title:@"Show old mnemonics"
                                               subtitle:@"Display old mnemonics alongside new ones"
                                                     on:Settings.showOldMnemonic
                                                 target:self
                                                 action:@selector(showOldMnemonicChanged:)]];
  [model
      addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                  title:@"Use katakana for onyomi readings"
                                               subtitle:nil
                                                     on:Settings.useKatakanaForOnyomi
                                                 target:self
                                                 action:@selector(useKatakanaForOnyomiChanged:)]];

  [model addSection:@"Audio"];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleSubtitle
                             title:@"Play audio automatically"
                          subtitle:@"When you answer correctly"
                                on:Settings.playAudioAutomatically
                            target:self
                            action:@selector(playAudioAutomaticallySwitchChanged:)]];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                 title:@"Offline audio"
                                              subtitle:nil
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapOfflineAudio:)]];

  [model addSection:@"Animations" footer:@"You can turn off any animations you find distracting"];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Particle explosion"
                          subtitle:nil
                                on:Settings.animateParticleExplosion
                            target:self
                            action:@selector(animateParticleExplosionSwitchChanged:)]];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Level up popup"
                          subtitle:nil
                                on:Settings.animateLevelUpPopup
                            target:self
                            action:@selector(animateLevelUpPopupSwitchChanged:)]];
  [model
      addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                  title:@"+1"
                                               subtitle:nil
                                                     on:Settings.animatePlusOne
                                                 target:self
                                                 action:@selector(animatePlusOneSwitchChanged:)]];

  [model addSection];
  [model addItem:[[TKMBasicModelItem alloc]
                     initWithStyle:UITableViewCellStyleSubtitle
                             title:@"Export local database"
                          subtitle:@"To attach to bug reports or email to the developer"
                     accessoryType:UITableViewCellAccessoryDisclosureIndicator
                            target:self
                            action:@selector(didTapSendBugReport:)]];

  TKMBasicModelItem *logOutItem =
      [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                         title:@"Log out"
                                      subtitle:nil
                                 accessoryType:UITableViewCellAccessoryNone
                                        target:self
                                        action:@selector(didTapLogOut:)];
  logOutItem.textColor = [UIColor redColor];
  [model addItem:logOutItem];

  _model = model;
  [model reloadTable];
}

- (NSString *)lessonOrderValueText {
  NSMutableArray<NSString *> *lessonOrderText = [NSMutableArray array];
  for (int i = 0; i < Settings.lessonOrder.count; i++) {
    TKMSubject_Type type = [Settings.lessonOrder objectAtIndex:i].intValue;
    [lessonOrderText addObject:TKMSubjectTypeName(type)];
  }
  return [lessonOrderText componentsJoinedByString:@", "];
}

- (NSString *)lessonBatchSizeText {
  return [NSString stringWithFormat:@"%d", Settings.lessonBatchSize];
}

- (NSString *)reviewOrderValueText {
  switch (Settings.reviewOrder) {
    case ReviewOrder_Random:
      return @"Random";
    case ReviewOrder_BySRSStage:
      return @"SRS stage";
    case ReviewOrder_CurrentLevelFirst:
      return @"Current level first";
    case ReviewOrder_LowestLevelFirst:
      return @"Lowest level first";
  }
  return nil;
}

- (NSString *)taskOrderValueText {
  if (Settings.meaningFirst) {
    return @"Meaning first";
  } else {
    return @"Reading first";
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;

  [self rerender];
}

- (void)animateParticleExplosionSwitchChanged:(UISwitch *)switchView {
  Settings.animateParticleExplosion = switchView.on;
}

- (void)animateLevelUpPopupSwitchChanged:(UISwitch *)switchView {
  Settings.animateLevelUpPopup = switchView.on;
}

- (void)animatePlusOneSwitchChanged:(UISwitch *)switchView {
  Settings.animatePlusOne = switchView.on;
}

- (void)prioritizeCurrentLevelChanged:(UISwitch *)switchView {
  Settings.prioritizeCurrentLevel = switchView.on;
}

- (void)groupMeaningReadingSwitchChanged:(UISwitch *)switchView {
  Settings.groupMeaningReading = switchView.on;
  [_model setIndexPath:_groupMeaningReadingIndexPath isHidden:!switchView.on];
}

- (void)showAnswerImmediatelySwitchChanged:(UISwitch *)switchView {
  Settings.showAnswerImmediately = switchView.on;
}

- (void)enableCheatsSwitchChanged:(UISwitch *)switchView {
  Settings.enableCheats = switchView.on;
}

- (void)showOldMnemonicChanged:(UISwitch *)switchView {
  Settings.showOldMnemonic = switchView.on;
}

- (void)useKatakanaForOnyomiChanged:(UISwitch *)switchView {
  Settings.useKatakanaForOnyomi = switchView.on;
}

- (void)playAudioAutomaticallySwitchChanged:(UISwitch *)switchView {
  Settings.playAudioAutomatically = switchView.on;
}

- (void)allReviewsSwitchChanged:(UISwitch *)switchView {
  [self promptForNotifications:switchView
                       handler:^(BOOL granted) {
                         Settings.notificationsAllReviews = granted;
                       }];
}

- (void)badgingSwitchChanged:(UISwitch *)switchView {
  [self promptForNotifications:switchView
                       handler:^(BOOL granted) {
                         Settings.notificationsBadging = granted;
                       }];
}

- (void)promptForNotifications:(UISwitch *)switchView
                       handler:(NotificationPermissionHandler)handler {
  if (_notificationHandler) {
    return;
  }
  if (!switchView.on) {
    handler(NO);
    return;
  }

  [switchView setOn:NO animated:YES];
  switchView.enabled = NO;
  __weak SettingsViewController *weakSelf = self;
  _notificationHandler = ^(BOOL granted) {
    dispatch_async(dispatch_get_main_queue(), ^{
      switchView.enabled = YES;
      [switchView setOn:granted animated:YES];
      handler(granted);

      SettingsViewController *strongSelf = weakSelf;
      if (strongSelf) {
        strongSelf->_notificationHandler = nil;
      }
    });
  };

  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  UNAuthorizationOptions options = UNAuthorizationOptionBadge | UNAuthorizationOptionAlert;
  UIApplication *application = [UIApplication sharedApplication];
  [center
      getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {
        switch (settings.authorizationStatus) {
          case UNAuthorizationStatusAuthorized:
          case UNAuthorizationStatusProvisional: {
            _notificationHandler(YES);
            break;
          }
          case UNAuthorizationStatusNotDetermined: {
            [center requestAuthorizationWithOptions:options
                                  completionHandler:^(BOOL granted, NSError *_Nullable error) {
                                    _notificationHandler(granted);
                                  }];
            break;
          }
          case UNAuthorizationStatusDenied: {
            dispatch_async(dispatch_get_main_queue(), ^{
              [application openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                            options:[NSDictionary dictionary]
                  completionHandler:nil];
            });
            break;
          }
        }
      }];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
  if (!_notificationHandler) {
    return;
  }
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center
      getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {
        BOOL granted = settings.authorizationStatus == UNAuthorizationStatusAuthorized;
        if (@available(iOS 12.0, *)) {
          granted |= settings.authorizationStatus == UNAuthorizationStatusProvisional;
        }
        _notificationHandler(granted);
      }];
}

- (void)didTapLessonOrder:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"lessonOrder" sender:self];
}

- (void)didTapLessonBatchSize:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"lessonBatchSize" sender:self];
}

- (void)didTapReviewOrder:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"reviewOrder" sender:self];
}

- (void)didTapFonts:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"fonts" sender:self];
}

- (void)didTapTaskOrder:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"taskOrder" sender:self];
}

- (void)didTapOfflineAudio:(id)sender {
  [self performSegueWithIdentifier:@"offlineAudio" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"fonts"]) {
    TKMFontsViewController *vc = (TKMFontsViewController *)segue.destinationViewController;
    [vc setupWithServices:_services];
  }
}

- (void)didTapLogOut:(id)sender {
  __weak SettingsViewController *weakSelf = self;
  UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                             message:nil
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [c addAction:[UIAlertAction
                   actionWithTitle:@"Log out"
                             style:UIAlertActionStyleDestructive
                           handler:^(UIAlertAction *_Nonnull action) {
                             NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
                             [nc postNotificationName:kLogoutNotification object:weakSelf];
                           }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)didTapSendBugReport:(id)sender {
  NSURL *url = [LocalCachingClient databaseFileUrl];
  UIActivityViewController *c = [[UIActivityViewController alloc] initWithActivityItems:@[ url ]
                                                                  applicationActivities:nil];
  [self presentViewController:c animated:YES completion:nil];
}

@end
