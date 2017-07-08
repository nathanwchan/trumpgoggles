//
//  ProfileViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 6/1/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit
import SwiftyJSON
import SafariServices

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TWTRTweetViewDelegate, SFSafariViewControllerDelegate {
    
    var list: TWTRList?
    var user: TWTRUserCustom?
    private var tweets: [TWTRTweet] = []
    private var showSpinnerCell: Bool = true
    private var showSorryCell: Bool = false
    private func errorOccurred(deleteList: Bool = false) {
        if self.showSorryCell {
            // acting as a lock to prevent multiple calls here to update UI
            return
        }
        self.showSpinnerCell = false
        self.showSorryCell = true
        DispatchQueue.main.async {
            self.profileTableView.reloadData()
        }
    }
    var profileCellInView: Bool = true
    var refreshControlEnabled: Bool = false
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh tweets")
        refreshControl.addTarget(self, action: #selector(self.handleRefresh(_:)), for: .valueChanged)
        return refreshControl
    }()
    
    @IBOutlet weak var profileTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.profileTableView.dataSource = self
        self.profileTableView.delegate = self
        
        // dynamic cell height based on inner content
        self.profileTableView.rowHeight = UITableViewAutomaticDimension
        self.profileTableView.estimatedRowHeight = 120
        // remove separator lines between empty rows
        self.profileTableView.tableFooterView = UIView(frame: CGRect.zero)
        
        DispatchQueue.main.async {
            let navigationTitleUILabel = UILabel()
            navigationTitleUILabel.text = "Trump Goggles"
            navigationTitleUILabel.font = UIFont(name: "HelveticaNeue-Bold", size: 17)
            navigationTitleUILabel.sizeToFit()
            self.navigationItem.titleView = navigationTitleUILabel
            self.navigationItem.titleView?.alpha = 0.0
        }
        
        let logoutButton = UIButton(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        logoutButton.setImage(UIImage(named: "exit.png"), for: .normal)
        logoutButton.addTarget(self, action: #selector(self.clickedLogoutButton(sender:)), for: .touchUpInside)
        let negativeSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        negativeSpacer.width = -8;
        self.navigationItem.rightBarButtonItems = [negativeSpacer, UIBarButtonItem(customView: logoutButton)]
        
        let client = TWTRAPIClient.withCurrentUser()
        var clientError: NSError?
        
        let getUserEndpoint = "https://api.twitter.com/1.1/users/show.json?screen_name=\(Constants.screenName)"
        let request = client.urlRequest(withMethod: "GET", url: getUserEndpoint, parameters: nil, error: &clientError)
        
        client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_users_show")
                self.errorOccurred()
                return
            }
            
            let jsonData = JSON(data: data)
            self.user = TWTRUserCustom(json: jsonData)
            
            guard let user = self.user else {
                print("Error: something went wrong serializing user")
                firebase.logEvent("serialize_user_error")
                self.errorOccurred()
                return
            }
            
            let getListEndpoint = "https://api.twitter.com/1.1/lists/show.json?owner_screen_name=\(Constants.publicListsTwitterAccount)&slug=\(Constants.listSlugId)"
            let request = client.urlRequest(withMethod: "GET", url: getListEndpoint, parameters: nil, error: &clientError)
            client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_lists_show")
                    self.errorOccurred()
                    return
                }
                
                let jsonData = JSON(data: data)
                self.list = TWTRList(json: jsonData, user: user)
                
                self.retrieveAndRenderListTweets()
            }
        }
    }
    
    func retrieveAndRenderListTweets(refresh: Bool = false) {
        guard let list = self.list else {
            print("Error: something went wrong serializing list")
            firebase.logEvent("serialize_list_error")
            self.errorOccurred()
            return
        }
        
        if list.memberCount == 0 {
            return
        }
        
        let getListTweetsEndpoint = "https://api.twitter.com/1.1/lists/statuses.json?list_id=\(list.idStr)"
        var params = [
            "count": "50"
        ]
        if !refresh {
            if let oldestTweet = self.tweets.last {
                if let tweetID = Int(oldestTweet.tweetID) {
                    params["max_id"] = String(describing: tweetID - 1)
                } else {
                    params["max_id"] = oldestTweet.tweetID
                }
                // attempt to prompt store review when loading more tweets
                attemptPromptStoreReview()
            }
        }
        let client = TWTRAPIClient.withCurrentUser()
        var clientError: NSError?
        let request = client.urlRequest(withMethod: "GET", url: getListTweetsEndpoint, parameters: params, error: &clientError)
        
        client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_lists_statuses")
                self.errorOccurred()
                return
            }
            
            let jsonData = JSON(data: data)
            let newTweets = TWTRTweet.tweets(withJSONArray: jsonData.arrayObject) as! [TWTRTweet]
            self.showSpinnerCell = false
            let when = DispatchTime.now() + 1 // intentionally delay by 1 second for better UX
            DispatchQueue.main.asyncAfter(deadline: when) {
                if refresh {
                    self.tweets = newTweets
                } else {
                    self.tweets.append(contentsOf: newTweets)
                }
                self.profileTableView.reloadData()
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    func handleRefresh(_: Any?) {
        firebase.logEvent("refresh_tweets")
        self.retrieveAndRenderListTweets(refresh: true)
    }
    
    func clickedLogoutButton(sender: Any?) {
        let alertController = UIAlertController(title: "Logout?", message: "Are you sure you want to logout of your Twitter account?", preferredStyle: .alert)
        let logoutAction = UIAlertAction(title: "Yes", style: .default) { (result : UIAlertAction) -> Void in
            self.logout()
        }
        let cancelAction = UIAlertAction(title: "No", style: .cancel) { (result : UIAlertAction) -> Void in }
        alertController.addAction(cancelAction)
        alertController.addAction(logoutAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func logout() {
        let store = Twitter.sharedInstance().sessionStore
        
        if let userID = store.session()?.userID {
            store.logOutUserID(userID)
            globals.launchCount = UserDefaults.standard.integer(forKey: Constants.launchCountUserDefaultsKey) - 1
            UserDefaults.standard.set(globals.launchCount, forKey: Constants.launchCountUserDefaultsKey)
            firebase.logEvent("logout_\(userID)")
        }
        
        DispatchQueue.main.async {
            self.navigationController?.viewControllers = []
            self.performSegue(withIdentifier: "LogoutSegue", sender: nil)
        }
    }
    
    func openUrlInModal(_ url: URL?) {
        if let url = url {
            if UIApplication.shared.canOpenURL(url) {
                let vc = SFSafariViewController(url: url, entersReaderIfAvailable: true)
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func openTwitterProfile(sender: Any?) {
        guard let user = self.user else {
            fatalError("User is not set.")
        }
        
        firebase.logEvent("profile_image_or_name_click")
        let profileUrl = URL(string: "https://twitter.com/\(user.screenName)")
        self.openUrlInModal(profileUrl)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 && self.user != nil {
            guard let profileCell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as? ProfileTableViewCell else {
                fatalError("The dequeued cell is not an instance of ProfileTableViewCell.")
            }
            let user = self.user!

            profileCell.profileImageButton.setImage(fromUrl: user.profileImageOriginalSizeUrl, for: .normal)
            profileCell.profileImageButton.layer.cornerRadius = 5
            profileCell.profileImageButton.clipsToBounds = true
            profileCell.profileImageButton.imageView?.contentMode = .scaleAspectFill
            profileCell.profileImageButton.addTarget(self, action: #selector(self.openTwitterProfile(sender:)), for: .touchUpInside)
            profileCell.nameButton.setTitle(user.name, for: .normal)
            profileCell.nameButton.addTarget(self, action: #selector(self.openTwitterProfile(sender:)), for: .touchUpInside)
            profileCell.screenNameLabel.text = "@\(user.screenName)"
            profileCell.isVerifiedImageView.isHidden = !user.isVerified
            profileCell.descriptionLabel.text = user.userDescription
            profileCell.whatNameSeesLabel.text = "What \(user.name) sees..."
            profileCell.followingLabel.text = abbreviateNumber(num: user.followingCount)
            return profileCell
        } else if self.showSpinnerCell {
            let spinnerCell = tableView.dequeueReusableCell(withIdentifier: "spinnerCell", for: indexPath) as UITableViewCell
            spinnerCell.separatorInset = UIEdgeInsetsMake(0, 0, 0, tableView.bounds.width);
            return spinnerCell
        } else if self.showSorryCell {
            let sorryCell = tableView.dequeueReusableCell(withIdentifier: "sorryCell", for: indexPath) as UITableViewCell
            return sorryCell
        } else {
            guard let tweetCell = tableView.dequeueReusableCell(withIdentifier: "tweetCell", for: indexPath) as? TWTRTweetTableViewCell else {
                fatalError("The dequeued cell is not an instance of TWTRTweetTableViewCell.")
            }
            
            tweetCell.configure(with: self.tweets[indexPath.row - 1])
            tweetCell.tweetView.showBorder = false
            tweetCell.tweetView.delegate = self
            return tweetCell
        }
    }
    
    func setNavigationBarItemsAlpha(hide: Bool = false) {
        if hide {
            DispatchQueue.main.async {
                self.navigationItem.titleView?.alpha = 0.0
            }
        } else if self.profileCellInView && !self.showSorryCell {
            let alpha = max(0, min(1, (self.profileTableView.contentOffset.y - 30) / 110))
            DispatchQueue.main.async {
                self.navigationItem.titleView?.alpha = alpha
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.setNavigationBarItemsAlpha()
        
        if !refreshControlEnabled && !self.profileCellInView {
            // only enable the refresh control once the user has scrolled down a little bit
            DispatchQueue.main.async {
                self.profileTableView.addSubview(self.refreshControl)
                self.refreshControlEnabled = true
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.user != nil ? 1 : 0) + self.tweets.count + (self.showSorryCell ? 1 : 0) + (self.showSpinnerCell ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && self.user != nil {
            self.profileCellInView = true
        }
        if indexPath.row == self.tweets.count - 3 {
            firebase.logEvent("profile_load_more_tweets")
            self.retrieveAndRenderListTweets()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && self.user != nil {
            self.profileCellInView = false
        }
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTap tweet: TWTRTweet) {
        firebase.logEvent("profile_tweet_click")
        self.openUrlInModal(tweet.permalink)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTapProfileImageFor user: TWTRUser) {
        firebase.logEvent("profile_tweet_profile_image_click")
        self.openUrlInModal(user.profileURL)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTap url: URL) {
        firebase.logEvent("profile_tweet_url_click")
        self.openUrlInModal(url)
    }
}
