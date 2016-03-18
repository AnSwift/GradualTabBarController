# GradualTabBarController

上图：

![TabBarColorAnimation](https://github.com/seedante/GradualTabBarController/blob/master/Figure/TabBarColorAnimation.gif?raw=true)


写 [iOS 视图控制器转场详解](https://github.com/seedante/iOS-Note/wiki/ViewController-Transition)时看到了 [WXTabBarController](https://github.com/leichunfeng/WXTabBarController) 的 TabBar 颜色渐变效果，试图在 UITabBarController 的转场过程中给 TabBar 加上渐变动画效果，当时遇到了点问题没完成，最近想起来了，解决了。

方法是获取 UITabBar 的内部视图结构，如果你没有 Reveal 这个软件，用 Xcode 自身的 ViewDebugging 也很方便，快速入门教程：raywenderlich 家出品的 [View Debugging in Xcode 6](https://www.raywenderlich.com/98356/view-debugging-in-xcode-6)。

图胜千言：

![UITabBar's subViews](http://upload-images.jianshu.io/upload_images/37334-1373acddbd4605a1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![WXTabBarController's TabBar](http://upload-images.jianshu.io/upload_images/37334-8cdd339a32376f07.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在原来的图标后面添加选中状态的图标，更新它们的 alpha 值就可以了。[WXTabBarController](https://github.com/leichunfeng/WXTabBarController)采用了 UIScrollView 来实现传统的转场效果，UIScrollView 在滑动过程直至结束都会调用`- (void)scrollViewDidScroll:(UIScrollView *)scrollView`，在这里实时更新 alpha 值就可以了。

而在交互转场中实现这个效果时，由于 UITabBarController 自身对 TabBar 的限制，会比较麻烦一点。SEGradualTabBarController 对 TabBar 的处理是下面这样的：

![SEGradualTabBarController's TabBar](http://upload-images.jianshu.io/upload_images/37334-5c17f3f722df8b12.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

大体就是这样，剩下的看代码吧。

掌握了内部视图结构，传统的 UIView 动画就可以派上用场了，可以玩出花来。
