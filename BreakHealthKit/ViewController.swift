//
//  ViewController.swift
//  BreakHealthKit
//
//  Created by Bo Jhang Ho on 3/22/17.
//  Copyright © 2017 Bo Jhang Ho. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    @IBOutlet var storeButton: UIButton!
    @IBOutlet weak var showStatusButton: UIButton!
    @IBOutlet var picker: UIPickerView!
    @IBOutlet weak var labelElaspedTime: UILabel!
    @IBOutlet weak var labelNumGoodSamples: UILabel!
    @IBOutlet weak var labelNumBadSamples: UILabel!
    @IBOutlet weak var labelGoodFreq: UILabel!
    @IBOutlet weak var labelErrorMsg: UILabel!
    @IBOutlet weak var labelTotalNumDataPoints: UILabel!
    
    
    let healthKitStore:HKHealthStore = HKHealthStore()
    
    let freqChoices = [1, 10, 100, 1000, 10000]
    let durationChoices = [1, 2, 5, 10, 30]
    var allChoices = [[String]]()
    
    var selFreq = 1
    var selDuration = 1
    
    var uiTimer: Timer? = nil
    var hkTimer: Timer? = nil
    var batchSize: Int = 0
    var numBatches: Int = 0
    
    var requestStartTime: Date? = nil
    var numProcessedPoints: Int = 0
    var numFailedPoints: Int = 0
    var numTotalPoints: Int = 0
    var numFinishedBatches: Int = 0
    var lastErrorMsg: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var tmpArr = [String]()
        for num in freqChoices {
            tmpArr.append(String(format: "%dHz", num))
        }
        allChoices.append(tmpArr)
        
        tmpArr.removeAll()
        for num in durationChoices {
            tmpArr.append(String(format: "%dsec%@", num, (num == 1 ? "" : "s")))
        }
        allChoices.append(tmpArr)
        
        let healthKitTypesToWrite: Set<HKSampleType> = [
            HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
            ]

        
        healthKitStore.requestAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToWrite) { (success, error) -> Void in
            print(success)
            if !success {
                print(error!)
            }
        }
        
        getTotalNumSamples(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func storeBPData(_ sender: AnyObject) {
        storeButton.isEnabled = false
        
        var timeInterval: Double
        if selFreq <= 100 {
            batchSize = 1
            timeInterval = 1.0 / Double(selFreq)
        }
        else {
            batchSize = selFreq / 100
            timeInterval = 0.01
        }
        
        numTotalPoints = selFreq * selDuration
        numBatches = numTotalPoints / batchSize
        requestStartTime = Date()
        numProcessedPoints = 0
        numFailedPoints = 0
        numFinishedBatches = 0
        lastErrorMsg = ""
        
        labelErrorMsg.text = ""
        
        hkTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(self.storeHRData), userInfo: nil, repeats: true);
        uiTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(self.uiUpdate), userInfo: nil, repeats: true);
    }
    
    @IBAction func getTotalNumSamples(_ sender: AnyObject) {
        showStatusButton.isEnabled = false
        labelTotalNumDataPoints.text = "(Calculating...)"
        
        let past = Date.distantPast
        let now  = Date()
        
        let mostRecentPredicate = HKQuery.predicateForSamples(withStart: past, end: now)
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let heartRateQuery = HKSampleQuery(sampleType: heartRateType,
                                           predicate: mostRecentPredicate,
                                           limit: Int(HKObjectQueryNoLimit),
                                           sortDescriptors: nil) { (query, results, error) -> Void in
            self.labelTotalNumDataPoints.text = String(format: "Retrieve %d heartrate samples", results!.count)
            self.showStatusButton.isEnabled = true
        }
        
        healthKitStore.execute(heartRateQuery)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return allChoices[component][row]
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return allChoices[component].count
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 0 {
            selFreq = freqChoices[row]
        }
        else {
            selDuration = durationChoices[row]
        }
        print(selFreq, selDuration)
    }
    
    func storeHRData() {
        var samples = [HKQuantitySample]()
        for i in 0 ..< batchSize {
            let beatsCountUnit = HKUnit.count()
            let numBeats = 50.0 + Double(i) / 10.0
            let heartRateQuantity = HKQuantity(unit: beatsCountUnit.unitDivided(by: HKUnit.minute()), doubleValue:numBeats)
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let startDate = Date()
            let endDate = startDate
            let heartRateSample = HKQuantitySample(type: heartRateType, quantity: heartRateQuantity, start: startDate, end: endDate)
            samples.append(heartRateSample)
        }
        healthKitStore.save(samples) { (success: Bool, error: Error?) in
            if success {
                self.numProcessedPoints += self.batchSize
            }
            else {
                self.lastErrorMsg = error!.localizedDescription
                self.numFailedPoints += self.batchSize
            }
        }

        numFinishedBatches += 1
        if numFinishedBatches == numBatches {
            hkTimer!.invalidate()
            storeButton.isEnabled = true
        }
    }
    
    func uiUpdate() {
        let timeElasped = Date().timeIntervalSince(requestStartTime!)
        let isDone = numProcessedPoints + numFailedPoints == numTotalPoints
        labelElaspedTime.text = String(format: "%.2lfsec", timeElasped) + (isDone ? "  (Done)" : "")
        labelNumGoodSamples.text = String(format: "%d", numProcessedPoints)
        labelNumBadSamples.text = String(format: "%d", numFailedPoints)
        labelGoodFreq.text = String(format: "%.2lfHz", Double(numProcessedPoints) / timeElasped)
        labelErrorMsg.text = lastErrorMsg
        if isDone {
            uiTimer?.invalidate()
            getTotalNumSamples(self)
        }
    }
}

