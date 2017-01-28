+++

banner = ""
categories = ["源码阅读"]
description = "JDK1.7+的革命性排序算法改进:TimSort与DualPivotQuickSort"
images = []
menu = ""
tags = ["排序算法","JDK"]
disable_profile = false
disable_widgets = true

title = "JDK7+的适应性排序系统"
date = "2017-01-28T08:36:54-07:00"

+++

---

>对于java.util.Arrays工具类中的排序算法,我们的一般印象是:对于primitive类型采用快速排序,而对于Object类型则采用归并排序;在JDK1.7之前,Arrays工具类所采用的快速排序与归并排序的确都是传统的快排与归并排序,然而从JDK1.7开始,Java官方革命性地改进了Arrays工具类中的排序算法:快速排序采用DualPivotQuickSort(双轴值快速排序)，而归并排序采用TimSort(适用性归并排序,以作者Tim Peter的名字命名).

### DualPivotQuickSort

一般的快速排序采用一个枢轴来把一个数组划分成两半,然后递归之.
大量经验数据表明,采用两个枢轴来划分成3份的算法更高效,这就是DualPivotQuicksort;
