//
//  IntroViewController.swift
//  Park Here
//
//  Created by Aditya Bansod on 1/17/15.
//  Copyright (c) 2015 Aditya Bansod. All rights reserved.
//

import UIKit

class IntroViewController: UIPageViewController, UIPageViewControllerDataSource {

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var pageTitles:[String] =
    
    ["Welcome to Park Here",
    "Find parking rules, street sweeping, meters and more all across SF",
    ""]
    
    var introPageViewController:UIPageViewController = UIPageViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        let pageControl = UIPageControl.appearance()
        pageControl.pageIndicatorTintColor = UIColor.lightGrayColor()
        pageControl.currentPageIndicatorTintColor = UIColor.blackColor()
        pageControl.backgroundColor = UIColor.whiteColor()

        
        introPageViewController = self.storyboard?.instantiateViewControllerWithIdentifier("IntroPageViewController") as UIPageViewController
        introPageViewController.dataSource = self;
        
        let startingViewController = viewControllerForIndex(0)!
        introPageViewController.setViewControllers([startingViewController], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
        
        introPageViewController.view.frame = CGRectMake(0,0, self.view.frame.size.width, self.view.frame.height)
        addChildViewController(introPageViewController)
        view.addSubview(introPageViewController.view)
        introPageViewController.didMoveToParentViewController(self)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        let introViewController = viewController as IntroContentViewController
        var index:Int = introViewController.pageIndex
        
        if index == 0 {
            return nil
        }
        
        index--
        return viewControllerForIndex(index)
    }
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        let introViewController = viewController as IntroContentViewController
        var index:Int = introViewController.pageIndex
        
        index++
        
        // if we're at the end of the intro, segue to the map view
        if index == self.pageTitles.count {
            self.performSegueWithIdentifier("IntroViewToMapViewSegue", sender: self)
            return nil
        }
        
        return viewControllerForIndex(index)
    }
    
    func viewControllerForIndex(index:Int) -> UIViewController? {
        if(pageTitles.count == 0 || index >= pageTitles.count) {
            return nil
        }
        
        let content = self.storyboard?.instantiateViewControllerWithIdentifier("IntroContentViewController") as IntroContentViewController
        content.labelText = pageTitles[index]
        content.pageIndex = index
        return content
    }
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return pageTitles.count
    }
    
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }
}
