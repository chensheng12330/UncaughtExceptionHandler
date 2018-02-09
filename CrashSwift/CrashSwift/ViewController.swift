//
//  ViewController.swift
//  CrashSwift
//
//  Created by sherwin.chen on 2018/2/9.
//  Copyright © 2018年 sherwin.chen. All rights reserved.
//

import UIKit



class ViewController: UIViewController {

    func gotoA() -> Void {
        var info = ["a","b"];
        
        var a = info[4]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        UncaughtExceptionHandler .installUncaughtException { (string1) in
            
        }
        gotoA()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

