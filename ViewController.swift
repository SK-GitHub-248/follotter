    func getTwitterDataV2(next_token: String) {
        
        var DataFollowingWork:[TwitterSettingNameV2.Data] = []
        var DataFollowing:[TwitterSettingNameV2.Data] = []

        var paginationToken = ""
        if next_token != "" {
            paginationToken = "&pagination_token=" + next_token
        }
        guard let url = URL(string: "https://api.twitter.com/2/users/" + strAccountId + "/following?user.fields=profile_image_url,public_metrics&max_results=1000" + paginationToken) else {
            return
        }

        let client = OAuthSwiftClient(
            consumerKey: consumerKey,
            consumerSecret: consumerKeySecret,
            oauthToken: strAccessToken,
            oauthTokenSecret: strAccessTokenSecret,
            version: .oauth1
        )

        client.get(url) { result in
            switch result {
            case .success(let response):
                if response.response.statusCode == 200 {

                    guard let settingV2 = try? JSONDecoder().decode(TwitterSettingNameV2.self, from: response.data) else {
                        return
                    }

                    DataFollowingWork.append(contentsOf: settingV2.data)

                    if settingV2.meta.next_token != nil {   //Recursively calls own method if there is a next page
                        self.getTwitterDataV2(next_token: settingV2.meta.next_token!)
                    } else {
                        //Save the acquired user list (ID)
                        var ids_API_V2:[Int] = []
                        for i in 0..<DataFollowingWork.count {
                            ids_API_V2.append(Int(DataFollowingWork[i].id) ?? 0)
                        }

                        //Obtain a list of users (IDs) stored in UserDefaults
                        let ids_UD = UserDefaults.standard.array(forKey: self.strAccountScreenName) as? [Int] ?? []
                        if ids_UD == [] {   //if not ...
                            self.ids = ids_API_V2   //Set global variables as they are with the values obtained from the API
                            DataFollowing = DataFollowingWork
                        } else if self.ids == [] {   //If global variable is empty (at initial display) (will not pass through here from the next page onward)
                            //API -> Search for UD and if it is not there, add it as a new minute.
                            for i in 0..<ids_API_V2.count {
                                let index = ids_UD.firstIndex(of: ids_API_V2[i])
                                if index == nil {
                                    self.ids.append(ids_API_V2[i])

                                    DataFollowing.append(DataFollowingWork.first{$0.id == String(ids_API_V2[i])}!)
                                }
                            }
                            //UD -> Search for APIs and add them if available
                            for i in 0..<ids_UD.count {
                                let index = ids_API_V2.firstIndex(of: ids_UD[i])
                                if index != nil {
                                    self.ids.append(ids_UD[i])

                                    DataFollowing.append(DataFollowingWork.first{$0.id == String(ids_UD[i])}!)
                                }
                            }
                            //If the ids created is different from ids_UD (list of users stored in UserDefaults), re-save it.
                            if ids_UD != self.ids {
                                UserDefaults.standard.set(self.ids, forKey: self.strAccountScreenName)
                            }
                        }

                        //display
                        for i in 0 ..< DataFollowing.count {
                        
                            let url = DataFollowing[i].profile_image_url
                            // perform a substitution
                            let urlBig = url.replacingOccurrences(of: "_normal.", with: ".")
                        
                            let info:GridData.Info = GridData.Info(statusesCount: DataFollowing[i].public_metrics.tweet_count)
                            self.data.append(GridData(identifier: UUID(), id: Int(DataFollowing[i].id) ?? 0, url: urlBig, name: DataFollowing[i].name, screenName: DataFollowing[i].username, info: info))
                        }
                        var snapshot = NSDiffableDataSourceSnapshot<Section, GridData>()
                        snapshot.appendSections([.main])
                        snapshot.appendItems(self.data)
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } else {
                    print("response.response.statusCode1:\(response.response.statusCode)")
                }
            case .failure(let error):

                if error.errorCode == -11 {

                    let str : String = error.errorUserInfo.description
                    if str.contains("Code=429") { // -> true Twitter API Limits
                        
			print("error:\(error)")

                    } else {
                        print("error.errorCode:\(error.errorCode)")
                        print("str:\(str)")
                    }
                } else {
                    print("error.errorCode:\(error.errorCode)")
                }
                break
            }
        }
    }
