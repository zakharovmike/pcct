//
//  main.swift
//  pcct
//
//  Created by Mikhail Zakharov on 2019-02-24.
//  Copyright © 2019 Mikhail Zakharov. All rights reserved.
//

import Foundation

var projectURL: URL!
var dataFileURL: URL!
//print(projectURL, dataFileURL)

enum OptionType: String {
  case setPath = "sp"
  case createComponent = "cc"
  case renameComponent = "rc"
  case moveComponent = "mc"
  case deleteComponent = "dc"
  case unspecified
  
  init(value: String) {
    switch value {
    case "sp": self = .setPath
    case "cc": self = .createComponent
    case "rc": self = .renameComponent
    case "mc": self = .moveComponent
    case "dc": self = .deleteComponent
    default: self = .unspecified
    }
  }
}

func getOption(_ option: String) -> (OptionType, String) {
  return (OptionType(value: option), option)
}

func initialize(_ option: OptionType) {
  let fileManager = FileManager.default
  let defaultDataFileURL: URL
  do {
    defaultDataFileURL = (try fileManager.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)).appendingPathComponent("pcct/savedData")
    print(defaultDataFileURL)
    
    if fileManager.fileExists(atPath: defaultDataFileURL.path) {
//      print("ha yes it does")
      
      do {
        let fileContent = try String(contentsOf: defaultDataFileURL)
        if fileContent == "" {
          print("Your project path is not set. Use \"pcct sp /path/to/project\" to set it.")
        } else {
          pcct.projectURL = URL(fileURLWithPath: fileContent)
          print("successfully initialized")
        }
      }
      catch {
        print("could not read file")
      }
      
    } else {
      if option != OptionType.setPath {
        print("Your project path is not set. Use \"pcct sp /path/to/project\" to set it.")
      }
    }
  }
  catch {
    print("sum ting wong, ya no?")
  }
}

func setProjectPath(_ path: String) {
//  let url = URL(fileURLWithPath: path)
  let fileManager = FileManager.default
  
  do {
    let appSupportURL = try fileManager.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    pcct.dataFileURL = appSupportURL.appendingPathComponent("pcct/savedData")
    
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: appSupportURL.path + "/pcct", isDirectory: &isDirectory) && isDirectory.boolValue {
      print("the folder exists")
      do {
        try path.write(to: pcct.dataFileURL, atomically: false, encoding: .utf8)
        pcct.projectURL = URL(fileURLWithPath: path)
//        print(pcct.projectURL!, pcct.dataFileURL!)
      }
      catch {
        print("Could not save project path.")
      }
    } else {
      do {
        try fileManager.createDirectory(at: appSupportURL.appendingPathComponent("pcct"), withIntermediateDirectories: false)
        try path.write(to: pcct.dataFileURL, atomically: false, encoding: .utf8)
        pcct.projectURL = URL(fileURLWithPath: path)
//        print(pcct.projectURL!, pcct.dataFileURL!)
      }
      catch {
        print("Could not create directory nor save project path.")
      }
    }
  }
  catch {
    print("Could not find the right location.")
  }
}


//let option = getOption("cc")
//let (option, value) = getOption("cc")
//print(option)
//print("\(option) and \(value)")

let argumentCount = CommandLine.argc - 1
let arguments = CommandLine.arguments
let (option, value) = getOption(arguments[1])
//print(arguments)
//print("\(option) and \(value)")

initialize(option)

switch option {
case .setPath:
  if argumentCount != 2 {
    if argumentCount > 2 {
      print("Too many arguments for \(option) option. Should have two.")
    } else {
      print("Too few arguments for \(option) option. Should have two.")
    }
  } else {
    setProjectPath(arguments[2])
  }
case .createComponent: break
case .renameComponent: break
case .moveComponent: break
case .deleteComponent: break
case .unspecified: print("You're doing something wrong.")
}
