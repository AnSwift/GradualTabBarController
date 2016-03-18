//
//  SEGradualTabBarController.swift
//  GradualTabBarControllerDemo
//
//  Created by seedante on 16/3/18.
//  Copyright © 2016年 seedante. All rights reserved.
//

import UIKit

enum TabScrollDirection{
    case Left, Right
}

/*
渐变动画的原理：
参考自https://github.com/leichunfeng/WXTabBarController，原本 TabBarItem 没有有关 UIView 属性的公开接口，但是你知道内部视图结构就好办了，这个方案通过在 TabBarItem 内部添加
选中状态的图标并控制前后景图标视图的 alpha 实现渐变效果，你运行一下用 ViewDebugging 功能看一下就清楚怎么回事了。而该方案对 TabBar 的切换是采用 scrollView 实现的。

我在写 https://github.com/seedante/iOS-Note/wiki/ViewController-Transition 这篇文章的时候想在 Tab 切换的时候添加这个效果，但是当时由于对 AutoLayout 不熟练，
效果一直没出来，后来时间紧就放弃了。这几天想起了这事，研究了下，使用转场来实现这个效果，老实说，成本比上面的方案高，还一堆麻烦事，不过都解决了。

渐变方案的核心还是上面的手法，只不过在 UITabBarController 的 tabBar 有很多限制，这是个只读属性，很多关键属性不能更改。被选中的 TabBarItem 无法更改前景图标，因此后面的用来伪装的后景图标
必须使用未选中状态的图像，这与剩下的 TaBarItem 恰好相反，因此在 TabBarItem 切换后，还必须再调整一次。

用手势控制转场动画时同步 TabBarItem 的变化就可以了，手势结束后效果的剩余部分就可以用传统的 UIView 动画来处理了，因为你已经掌握了视图结构了，不需要用 CADisplayLink 来处理。
相关文章说明：http://www.jianshu.com/p/b14c893a400a
*/

class SEGradualTabBarController: UITabBarController, UITabBarControllerDelegate, UIViewControllerAnimatedTransitioning{
    
    var transitionDuration: NSTimeInterval = 0.3
    private var panGesture: UIPanGestureRecognizer = UIPanGestureRecognizer()
    private var interactionController = UIPercentDrivenInteractiveTransition()
    private var interactive = false
    private var scrollDirection: TabScrollDirection = .Left
    
    private var subViewControllerCount: Int{
        let count = viewControllers != nil ? viewControllers!.count : 0
        return count
    }
    
    private var tabBarButtons: [UIView] = []
    
    override var viewControllers: [UIViewController]?{
        willSet{
            cleanTabBar()
        }
        didSet{
            configureTabBar()
        }
    }
    
    override func setViewControllers(viewControllers: [UIViewController]?, animated: Bool) {
        cleanTabBar()
        super.setViewControllers(viewControllers, animated: animated)
        configureTabBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        
        panGesture.addTarget(self, action: "handlePan:")
        view.addGestureRecognizer(panGesture)
    }
    
    override func viewDidAppear(animated: Bool) {
        cleanTabBar()
        super.viewDidAppear(animated)
        configureTabBar()
    }
    
    
    /*Handle child viewcontroller transition.*/
    //MARK: TabBarController Delegate
    func tabBarController(tabBarController: UITabBarController, animationControllerForTransitionFromViewController fromVC: UIViewController, toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning?{
        return self
    }
    
    func tabBarController(tabBarController: UITabBarController, interactionControllerForAnimationController animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactive ? interactionController : nil
    }
    
    //MARK: Animation Controller Method
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return transitionDuration
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        guard let containerView = transitionContext.containerView(), fromVC = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey), toVC = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey) else{
            return
        }
        
        let fromIndex = self.viewControllers!.indexOf(fromVC)!
        let toIndex = self.viewControllers!.indexOf(toVC)!
        
        scrollDirection = toIndex < fromIndex ? .Right : .Left
        
        let fromView = fromVC.view
        let toView = toVC.view
        
        var translation = containerView.frame.width
        var toViewTransform = CGAffineTransformIdentity
        var fromViewTransform = CGAffineTransformIdentity
        
        translation = scrollDirection == .Left ? -translation : translation
        fromViewTransform = CGAffineTransformMakeTranslation(translation, 0)
        toViewTransform = CGAffineTransformMakeTranslation(-translation, 0)
        
        containerView.addSubview(toView)
        toView.transform = toViewTransform
        
        UIView.animateWithDuration(transitionDuration(transitionContext), animations: {
            fromView.transform = fromViewTransform
            toView.transform = CGAffineTransformIdentity
            }, completion: { finished in
                fromView.transform = CGAffineTransformIdentity
                toView.transform = CGAffineTransformIdentity
                
                let isCancelled = transitionContext.transitionWasCancelled()
                transitionContext.completeTransition(!isCancelled)
        })
    }
    
    //MARK: Configure TabBar Whenever ViewControllers Change.
    //TabBarItem 有可能发生变化前，将伪装的视图清除。
    private func cleanTabBar(){
        for subView in tabBar.subviews{
            if String(subView.dynamicType) == "UITabBarButton"{
                if subView.subviews.count == 4{
                    subView.subviews[1].removeFromSuperview()
                    subView.subviews[0].removeFromSuperview()
                }
            }
        }
        tabBarButtons.removeAll()
    }
    
    /*
    除了更新 viewControllers，这个方法到底在哪里调用好呢？特别是考虑到你会使用 storyboard 或者直接用代码生成该类对象，似乎两手都要准备，但是 awakeFromNib()里布局还没有完成，这里调用布局会有问题；viewDidLayoutSubviews()布局已经完成，但是调用很频繁，我老觉得浪费电；viewDidAppear(animated: Bool)才是最合适的地方，布局已完成，而且不会频繁调用，当实例消失又重新出现时，还会检查一次。
    */
    private func configureTabBar(){
        for subView in tabBar.subviews{
            if String(subView.dynamicType) == "UITabBarButton"{
                //门到底关了没，再次检查。
                if subView.subviews.count == 4{
                    subView.subviews[1].removeFromSuperview()
                    subView.subviews[0].removeFromSuperview()
                }
                tabBarButtons.append(subView)
            }
        }
        
        for (index, tabBarButton) in tabBarButtons.enumerate(){
            let originalImageView = tabBarButton.subviews[0] as! UIImageView
            let originalLabel = tabBarButton.subviews.last as! UILabel
            let tabBarItem = self.viewControllers?[index].tabBarItem
            
            //这里使用 frame 来定位非常方便，使用 AutoLayout 就比较繁琐，而且我照着写的约束把我坑死了，还不知道问题在哪里。
            let initialImage = index == selectedIndex ? tabBarItem?.image : tabBarItem?.selectedImage
            let imageView = UIImageView(image: initialImage)
            tabBarButton.insertSubview(imageView, atIndex: 0)
            imageView.frame = originalImageView.frame
            
            //这里会有点小瑕疵，TabBarItem 的颜色状态有两种，未选中状态的 TabBarItem 背后是添加选中状态时的伪装view，而被选中的 TabBarItem 背后的伪装view 则是未选中状态下的，
            //所有的后景 Label 的字体颜色直接采用了 TabBar 的 tintColor，而被选中的 TabBarItem 的后景 Label 的字体颜色应该是未选中状态，这里没有去处理这点，因为太麻烦了。
            let label = UILabel()
            label.textColor = tabBar.tintColor
            label.font = originalLabel.font
            label.text = tabBar.items?[index].title
            tabBarButton.insertSubview(label, atIndex: 1)
            label.frame = originalLabel.frame
            
            imageView.alpha = 0
            label.alpha = 0
        }
    }
    
    //MARK: Change Color Gradually.
    @objc private func handlePan(panGesture: UIPanGestureRecognizer){
        let translationX =  panGesture.translationInView(view).x
        let translationAbs = translationX > 0 ? translationX : -translationX
        let progress = translationAbs / view.frame.width
        switch panGesture.state{
        case .Began:
            let velocityX = panGesture.velocityInView(view).x
            if velocityX < 0{
                if selectedIndex < subViewControllerCount - 1{
                    interactive = true
                    selectedIndex += 1
                }else{
                    interactive = false
                }
            }else {
                if selectedIndex > 0{
                    interactive = true
                    selectedIndex -= 1
                }else{
                    interactive = false
                }
            }
        case .Changed:
            if interactive == false{return}
            updateTabBarWithAlpha(progress)
            interactionController.updateInteractiveTransition(progress)
        case .Cancelled, .Ended:
            if interactive == false{return}
            let newSelectdTabBarButton = tabBarButtons[selectedIndex]
            let oldSelectedIndex = scrollDirection == .Left ? selectedIndex - 1 : selectedIndex + 1
            let oldSelectedTabBarButton = tabBarButtons[oldSelectedIndex]
            if progress > 0.4{
                let duration = transitionDuration * NSTimeInterval(1 - progress)
                UIView.animateWithDuration(duration, animations: {
                    self.animateTabBarButton(newSelectdTabBarButton, transitionFinished: true)
                    self.animateTabBarButton(oldSelectedTabBarButton, transitionFinished: true)
                    }, completion: {_ in
                        self.resetTabBarButton(newSelectdTabBarButton, highlighted: true, atIndex: self.selectedIndex)
                        self.resetTabBarButton(oldSelectedTabBarButton, highlighted: false, atIndex: oldSelectedIndex)
                })
                //Bug in UITabBarController Transition: when completionSpeed == 1.0, something wrong.
                interactionController.completionSpeed = 0.99
                interactionController.finishInteractiveTransition()
            }else{
                let duration = transitionDuration * NSTimeInterval(progress)
                UIView.animateWithDuration(duration, animations: {
                    self.animateTabBarButton(newSelectdTabBarButton, transitionFinished: false)
                    self.animateTabBarButton(oldSelectedTabBarButton, transitionFinished: false)
                    }, completion: {_ in
                })
                interactionController.completionSpeed = 0.99
                interactionController.cancelInteractiveTransition()
            }
            interactive = false
        default: break
        }
    }
    
    private func updateTabBarWithAlpha(alpha: CGFloat){
        let newSelectdTabBarButton = tabBarButtons[selectedIndex]
        let oldSelectedIndex = scrollDirection == .Left ? selectedIndex - 1 : selectedIndex + 1
        let oldSelectedTabBarButton = tabBarButtons[oldSelectedIndex]
        updateTabBarButton(newSelectdTabBarButton, withAlpha: alpha)
        updateTabBarButton(oldSelectedTabBarButton, withAlpha: alpha)
    }
    
    private func updateTabBarButton(tabbarButton: UIView, withAlpha alpha: CGFloat){
        tabbarButton.subviews[0].alpha = alpha
        tabbarButton.subviews[1].alpha = alpha
        tabbarButton.subviews[2].alpha = 1 - alpha
        tabbarButton.subviews[3].alpha = 1 - alpha
    }
    
    private func animateTabBarButton(tabbarButton: UIView, transitionFinished finished: Bool){
        tabbarButton.subviews[0].alpha = finished ? 1 : 0
        tabbarButton.subviews[1].alpha = finished ? 1 : 0
        tabbarButton.subviews[2].alpha = finished ? 0 : 1
        tabbarButton.subviews[3].alpha = finished ? 0 : 1
    }
    
    //由于无法更改选中的 TabBarItem
    private func resetTabBarButton(tabbarButton: UIView, highlighted: Bool, atIndex index: Int){
        let imageView = tabbarButton.subviews[0] as! UIImageView
        if highlighted{
            imageView.image = self.viewControllers?[index].tabBarItem.image
        }else{
            imageView.image = self.viewControllers?[index].tabBarItem.selectedImage
        }
        
        imageView.alpha = 0
        tabbarButton.subviews[1].alpha = 0
        tabbarButton.subviews[2].alpha = 1
        tabbarButton.subviews[3].alpha = 1
    }
    
}

