//
//  OptimizelyService.swift
//
//  Created by Creative CX.
//  Copyright © 2019. All rights reserved.


import Foundation
import OptimizelySDKiOS


//ADD WHITELISTING CAPABILITIES


final class OptimizelyService {
   
    var optimizelyClient: OPTLYClient?
    var optimizelyManager: OPTLYManager?
    
    private let sdkKey = "" //SDK Key String
    private let jsonDataFile = "" //Link to the json datafile provided in settings in
                                 //Optimizely Dashboard
    private let datafileManagerDownloadInternal = 120
    
    private init() {}
    
    private static var _shared: OptimizelyService?
    
    //This block of code is to prevent race conditions
    //As this is a singleton class
    
    public static var shared: OptimizelyService {
        get {
            if _shared == nil {
                DispatchQueue.global().sync(flags: .barrier) {
                    if _shared == nil {
                        _shared = OptimizelyService()
                    }
                }
            }
            return _shared!
        }
    }
    
   
    
    //INITIALIZE OPTIMIZELY CLIENT
    
    func initializeOptimizelyClient(completion: @escaping (Result<OPTLYClient?>) -> Void) {
        
        let datafileManager = OPTLYDatafileManagerDefault(builder:      OPTLYDatafileManagerBuilder(block: { (builder) in
            builder!.datafileFetchInterval =   TimeInterval(self.datafileManagerDownloadInternal)
            builder!.datafileConfig = OPTLYDatafileConfig(projectId: nil, withSDKKey:self.sdkKey)!;
        }))
        
        let builder = OPTLYManagerBuilder(block: { (builder) in
            builder!.projectId = nil;
            builder!.sdkKey = self.sdkKey
            builder!.datafileManager = datafileManager!
            builder!.eventDispatcher = OPTLYEventDispatcherDefault()
        })
        
        self.optimizelyManager = OPTLYManager(builder: builder)
        self.optimizelyManager?.initialize(callback: { (error, optimizelyClient) in
            self.optimizelyClient = optimizelyClient
            if error != nil {
                completion(.error(nil))
            } else {
                self.optimizelyClient = optimizelyClient
                completion(.success(optimizelyClient))
            }
        })
        
    }
    
    
    //INITIALIZE OPTIMIZELY CLIENT AND ACTIVATE EXPERIMENT
    
    //initializing Optimizely Client
    //Using the default event dispatcher
    //Also added the interval for the datafile polling
    
    func initializeOptimizelyAndActivateExperiment(experimentId: String, userId: String, attributes: [String:NSObject]?, completion: @escaping (Result<String?>) -> Void) {
        
       //initializing the datafile Manager with the interval for the datafile polling
        
       let datafileManager = OPTLYDatafileManagerDefault(builder:      OPTLYDatafileManagerBuilder(block: { (builder) in
            builder!.datafileFetchInterval =   TimeInterval(self.datafileManagerDownloadInternal)
            builder!.datafileConfig = OPTLYDatafileConfig(projectId: nil, withSDKKey:self.sdkKey)!;
        }))
        
        let builder = OPTLYManagerBuilder(block: { (builder) in
            builder!.projectId = nil;
            builder!.sdkKey = self.sdkKey
            builder!.datafileManager = datafileManager!
            builder!.eventDispatcher = OPTLYEventDispatcherDefault()
        })
        
        self.optimizelyManager = OPTLYManager(builder: builder)
        self.optimizelyManager?.initialize(callback: { (error, optimizelyClient) in
            self.optimizelyClient = optimizelyClient
            if error != nil {
                completion(.error(nil))
            } else {
                let variation = optimizelyClient?.activate(experimentId, userId: userId, attributes: attributes)
                completion(.success(variation?.variationKey))
            }
        })
    }
    
    //IS FEATURE ENABLED
    
    //Checking if the feature is enabled
    func isFeatureEnabled(feature: String, userId: String) -> Bool {
        if let isEnabled = self.optimizelyClient?.isFeatureEnabled(feature, userId: userId) {
            if isEnabled {
                return true
                //dispatch to segment: FeatureId
            } else {
                return false
            }
            
        } else {
            return false
        }
    }
    
    //ACTIVATE A SINGLE EXPERIMENT
    
    //Activates the experiment and returns a variation key: Activate single experiment
    func activateForABTesting(experimentId: String, userId: String, attributes: [String:NSObject]?, completion: @escaping (Result<String?>) -> Void) {
        let variation = self.optimizelyClient?.activate(experimentId, userId: userId, attributes: attributes)
        if variation == nil {
            completion(.error(nil))
        } else {
            completion(.success(variation?.variationKey))
            //dispatch to segment experiment Id variation key
        }
    }
    
    //GET VARIATION KEY
    
    //Returns variation key with out activating the experiment
    func getVariationKey(experimentId: String, userId: String, attributes: [String:NSObject]?, completion: @escaping (Result<String?>) -> Void){
        if attributes == nil {
            let variation = optimizelyClient?.variation(experimentId, userId: userId, attributes: nil)
            if variation == nil {
                completion(.error(nil))
            } else {
                completion(.success(variation?.variationKey))
            }
        } else {
           let variation = optimizelyClient?.variation(experimentId, userId: userId, attributes:attributes)
            if variation == nil {
                completion(.error(nil))
            } else {
                completion(.success(variation?.variationKey))
            }
        }
    
    }
    
    //GET FEATURE VARIABLES
    
    //Get Feature Variables
    func getFeatureVariableInteger(featureKey: String,variableKey: String,userId: String, attributes: [String: NSObject]?) -> NSNumber? {
        return self.optimizelyClient?.getFeatureVariableInteger(featureKey, variableKey: variableKey, userId: userId, attributes: attributes)
    }
    
    func getFeatureVariableDouble(featureKey: String,variableKey: String,userId: String, attributes: [String: NSObject]?) -> NSNumber? {
        return self.optimizelyClient?.getFeatureVariableDouble(featureKey, variableKey: variableKey, userId: userId, attributes: attributes)
    }
    
    func getFeatureVariableString(featureKey: String,variableKey: String,userId: String, attributes: [String: NSObject]?) -> String? {
        return self.optimizelyClient?.getFeatureVariableString(featureKey, variableKey: variableKey, userId: userId, attributes: attributes)
    }
    
    //MARK: TRACK EVENTS
    
    //Track events
    func trackEvent(event: String, userId: String, attributes: [String: NSObject]? = nil) {
        if attributes == nil {
            self.optimizelyClient?.track(event, userId: userId)
        } else {
            self.optimizelyClient?.track(event, userId: userId, attributes: attributes!)
        }
    }
    
    //MARK: CHECK ACTIVE EXPERIMENTS
    
    //This function loops through the array of experiment ids and finds the ones that are active
    //then places them in an array and returns a list of the active experiment ids
    func checkActiveExperiments() -> [String?] {
        let ex = Experiments.getExperiments()
        var userId = String()
        if UserProfileService.shared.getUserId() == nil {
            userId = UserProfileService.shared.getUserProfile().userId
        } else {
            userId = UserProfileService.shared.getUserId()!
        }
        var activeExperiments = [String]()
        
        for a in ex  {
            getVariationKey(experimentId: a, userId: userId, attributes: nil, completion: {
                (result) in
            
                switch result {
                case .error(_):
                    print("\(a) is not active")
                case .success(let s):
                    print("\(a)'s Variation is: \(String(describing: s)) ")
                    activeExperiments.append(a)
                    
                }
            })
        }
        return activeExperiments
    }
    
}

enum Result<T> {
    case success(T)
    case error(T)
}
