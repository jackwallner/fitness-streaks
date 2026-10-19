package com.jackwallner.streaks.ui.nav

import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.Saver

class Navigation(tab: Int=0,stacks: List<List<String>> = List(3){listOf("home")}) {
    var tab by mutableIntStateOf(tab);private set
    var stacks by mutableStateOf(stacks);private set
    val route get()=stacks[tab].last()
    fun select(value: Int){tab=value}
    fun push(route: String){stacks=stacks.mapIndexed{i,s->if(i==tab)s+route else s}}
    fun back(): Boolean {if(stacks[tab].size<=1)return false;stacks=stacks.mapIndexed{i,s->if(i==tab)s.dropLast(1)else s};return true}
    companion object {val saver=Saver<Navigation,List<String>>(save={listOf(it.tab.toString())+it.stacks.map{s->s.joinToString("|")}},restore={Navigation(it.first().toInt(),it.drop(1).map{s->s.split('|')})})}
}
