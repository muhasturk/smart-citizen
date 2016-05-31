/**
 * Copyright (c) 2016 Mustafa Hastürk
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import Alamofire
import SwiftyJSON

class ProfileVC: AppVC {
  
  @IBOutlet weak var profileImageView: UIImageView!
  @IBOutlet weak var userName: UILabel!
  @IBOutlet weak var role: UILabel!
  @IBOutlet weak var profileSegment: UISegmentedControl!
  @IBOutlet weak var profileTable: UITableView!
  
  var firstNetworking = true
  private var requestBaseURL: String {
    return AppAPI.serviceDomain + AppAPI.profileServiceURL + String(AppReadOnlyUser.id)
  }
  
  var reportsDict: [String: [Report]] = [:]
  var refreshControl: UIRefreshControl!
  
  private func configureTableView() {
    refreshControl = UIRefreshControl()
    refreshControl.tintColor = UIColor.redColor()
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(self.profileNetworking), forControlEvents: UIControlEvents.ValueChanged)
    self.profileTable.addSubview(refreshControl)
  }
  
  // MARK: - LC
  override func viewDidLoad() {
    super.viewDidLoad()
    self.configureUI()
    self.configureTableView()
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(true)
    self.profileNetworking()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  override func viewWillAppear(animated: Bool) {
    self.navigationController?.navigationBarHidden = true
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    if (self.navigationController?.topViewController != self) {
      self.navigationController?.navigationBarHidden = false
    }
  }
  
  // MARK: Indicator
  func tableViewIndicator() {
    appIndicator = UIActivityIndicatorView(frame: CGRectMake(0, 0, 100, 100))
    appIndicator.center = self.profileTable.center
    appIndicator.hidesWhenStopped = true
    appIndicator.activityIndicatorViewStyle = .Gray
    self.view.addSubview(appIndicator)
    appIndicator.startAnimating()
  }
  
  
  
  // MARK: - Model
  private func writeUserDataToModel(dataJsonFromNetworking data: JSON) {
    self.reportsDict = [:]
    for (statusName, statusArrayJSON): (String, JSON) in data {
      self.reportsDict[statusName] = []
      for (_, statusArrayJSON): (String, JSON) in statusArrayJSON {
        let r = Report()
        r.id = statusArrayJSON["id"].intValue
        r.title = statusArrayJSON["title"].stringValue
        r.description = statusArrayJSON["description"].stringValue
        r.count = statusArrayJSON["count"].intValue
        r.category = statusArrayJSON["category"].stringValue
        r.categoryId = statusArrayJSON["categoryId"].intValue
        r.status = statusArrayJSON["status"].stringValue
        r.statusId = statusArrayJSON["statusId"].intValue
        r.imageUrl = statusArrayJSON["imageUrl"].stringValue
        self.reportsDict[statusName]?.append(r)
      }
    }
  }
  
  
  // MARK: - Table
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("profileCell", forIndexPath: indexPath)
    
    var tabReports = [Report]()
    switch self.profileSegment.selectedSegmentIndex {
    case 0:
      if let reports = self.reportsDict["1"] {
        tabReports = reports
      }
    case 1:
      if let reports = self.reportsDict["2"] {
        tabReports = reports
      }
    case 2:
      if let reports = self.reportsDict["3"] {
        tabReports = reports
      }
    case 3:
      if let reports = self.reportsDict["4"] {
        tabReports = reports
      }
    default:
      break
    }
    if tabReports.isEmpty {
      return UITableViewCell()
    }
    else {
      cell.textLabel?.text = tabReports[indexPath.row].title
      return cell
    }
  }
  
  override func viewWillLayoutSubviews() {
    self.profileImageView.layer.cornerRadius = (self.profileImageView.frame.height) / 2
    self.profileImageView.clipsToBounds = true
  }
  
  private func configureUI() {
    //    if AppReadOnlyUser.profileImageURL.isNotEmpty() {
    //      let url = NSURL(string: AppReadOnlyUser.profileImageURL)
    //        self.profileImageView.hnk_setImageFromURL(url)
    //    }
    self.userName.text = AppReadOnlyUser.fullName
    self.role.text = AppReadOnlyUser.roleName
  }
  
}

// MARK: - Networking
extension ProfileVC {
  func profileNetworking() {
    if firstNetworking {
      self.tableViewIndicator()
    }
    
    Alamofire.request(.GET, self.requestBaseURL, encoding: .JSON)
      .responseJSON { response in
        if self.firstNetworking {
          self.appIndicator.stopAnimating()
          self.firstNetworking = false
        }
        
        switch response.result {
        case .Success(let value):
          print(AppDebugMessages.serviceConnectionProfileIsOk, self.requestBaseURL, separator: "\n")
          let json = JSON(value)
          let serviceCode = json["serviceCode"].intValue
          
          if serviceCode == 0 {
            let data = json["data"]
            self.profileNetworkingSuccessful(data)
          }
            
          else {
            let exception = json["exception"]
            self.profileNetworkingUnsuccessful(exception)
          }
          
        case .Failure(let error):
          self.createAlertController(title: AppAlertMessages.networkingFailuredTitle, message: AppAlertMessages.networkingFailuredMessage, controllerStyle: .Alert, actionStyle: .Destructive)
          debugPrint(error)
        }
    }
  }
  
  private func profileNetworkingSuccessful(data: JSON) {
    self.writeUserDataToModel(dataJsonFromNetworking: data)
    self.profileTable.reloadData()
    if self.refreshControl.refreshing {
      self.refreshControl.endRefreshing()
    }
  }
  
  private func profileNetworkingUnsuccessful(exception: JSON) {
    let c = exception["exceptionCode"].intValue
    let m = exception["exceptionMessage"].stringValue
    let (title, message) = self.getHandledExceptionDebug(exceptionCode: c, elseMessage: m)
    self.createAlertController(title: title, message: message, controllerStyle: .Alert, actionStyle: .Default)
  }

}
