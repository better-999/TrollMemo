

这是一份巨魔项目代码，拷贝自开源项目TrollSpeed，现在命名为TrollMemo。
TrollSpeed可以正常打包ipa并使用巨魔商店安装
TrollMemo打包ipa后，却没法通过巨魔商店安装。
目前这个项目版本回退到了最初始的状态。
而@examples\TrollMemo 里面是之前失败的改造代码
@examples\TrollMemo里面的改造，参考的一个非开源的ipa包：XLsnowState.ipa，但是它的进程控制与桌面文字显示，总是被后台杀掉了。没有TrollSpeed.ipa显示的那么稳定。
这几个是XLsnowState.ipa的界面参考：@examples\20260616104839_1_84.jpg，@examples\20260616104840_2_84.jpg，@examples\20260616104841_3_84.jpg，红色的字就是固定在界面保持不动的，类似TrollSpeed的流量显示。但是我只需要文字。
现在的问题是：
1. TrollSpeed只能在桌面显示流量，但是我需要的是文字，而且这个的进程非常稳定，不会被杀进程。
2. XLsnowState可以在桌面显示文字，但是进程不稳定，容易被杀掉，而且这个闭源，没法找到源码改造。
3. 我做的@examples\TrollMemo可以说已经做完了，但是无法正常打包，也不知道原因。
4. 如果能分析出具体原因，则继续在@examples\TrollMemo里面改造。
5. 如果确实搞不定，想在这个项目上重新开发，只能推倒旧的@examples\TrollMemo，重新在这份代码里面开发改造，开发的界面仍然参考：@examples\20260616104839_1_84.jpg，@examples\20260616104840_2_84.jpg，@examples\20260616104841_3_84.jpg。







