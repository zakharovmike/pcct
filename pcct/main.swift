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

enum OptionType: String {
  case setPath = "sp"
  case createComponent = "cc"
  case moveComponent = "mc"
  case deleteComponent = "dc"
  case unspecified
  
  init(value: String) {
    switch value {
    case "sp": self = .setPath
    case "cc": self = .createComponent
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
    defaultDataFileURL = (try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)).appendingPathComponent("pcct/savedData")
    
    if fileManager.fileExists(atPath: defaultDataFileURL.path) {
      do {
        let fileContent = try String(contentsOf: defaultDataFileURL)
        if fileContent == "" {
          print("Your project path is not set. Use \"pcct sp /path/to/project\" to set it.")
        } else {
          pcct.projectURL = URL(fileURLWithPath: fileContent)
          pcct.dataFileURL = defaultDataFileURL
        }
      }
      catch {
        print("Could not read data file.")
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
  let fileManager = FileManager.default
  
  do {
    let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    pcct.dataFileURL = appSupportURL.appendingPathComponent("pcct/savedData")
    
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: appSupportURL.path + "/pcct", isDirectory: &isDirectory) && isDirectory.boolValue {
      do {
        try path.write(to: pcct.dataFileURL, atomically: true, encoding: .utf8)
        pcct.projectURL = URL(fileURLWithPath: path)
      }
      catch {
        print("Could not save project path.")
      }
    } else {
      do {
        try fileManager.createDirectory(at: appSupportURL.appendingPathComponent("pcct"), withIntermediateDirectories: false)
        try path.write(to: pcct.dataFileURL, atomically: true, encoding: .utf8)
        pcct.projectURL = URL(fileURLWithPath: path)
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

func copyTemplate(_ templateFile: String) -> String {
  let supportDirectoryURL = pcct.dataFileURL.deletingLastPathComponent()
  let templateURL = supportDirectoryURL.appendingPathComponent(templateFile)
  
  do {
    let fileContent = try String(contentsOf: templateURL)
    return fileContent
  }
  catch {
    print("Could not read template.")
  }
  
  return ""
}

func replaceName(here: String, with: String) -> String {
  let withSplit = with.split(separator: "-")
  let withSplitCapped = withSplit.map({ word in word.capitalized  })
  let camelCaseComponentName = withSplitCapped.joined()
  
  var lines = here.components(separatedBy: .newlines)
  for (index, line) in lines.enumerated() {
    if line.contains("<name-here>") {
      let replacedLine = line.replacingOccurrences(of: "<name-here>", with: camelCaseComponentName + "Component")
      lines[index] = replacedLine
    }
  }
  return lines.joined(separator: "\n")
}

func addToComponents(_ componentPath: String) -> Int {
  let componentName = componentPath.split(separator: "/").last!
  let componentNameSplit = componentName.split(separator: "-")
  let componentNameSplitCapped = componentNameSplit.map({ word in word.capitalized  })
  let camelCaseComponentName = componentNameSplitCapped.joined()
  let componentsFileURL = pcct.projectURL.appendingPathComponent("src/config/components.ts")
  
  do {
    let fileContent = try String(contentsOf: componentsFileURL)
    var lines = fileContent.components(separatedBy: .newlines)
    let importLines = lines[1..<lines.count].filter({ line in line.hasPrefix("import") })
    let startOfExportLines = lines.firstIndex(of: "export const components: ComponentDefinition[] = [")!
    let endOfExportLines = lines.firstIndex(of: "];")!

    let newImportPath = "'../components/" + componentPath + "/" + componentName + ".component';"
    let newImportLine = "import { " + camelCaseComponentName + "Component" + " } from " + newImportPath
    
    var pathsOfImportLines = importLines.map({ line in line.components(separatedBy: " ")[5] })
    pathsOfImportLines.append(newImportPath)
    let sortedPathsOfImportLines = pathsOfImportLines.sorted()
    let index = sortedPathsOfImportLines.firstIndex(of: newImportPath)!
    
    lines.insert(newImportLine, at: index + 1)

    if startOfExportLines + index + 2 == endOfExportLines + 1 {
      lines[endOfExportLines] += ","
      lines.insert("  \(camelCaseComponentName)Component", at: startOfExportLines + index + 2)
    } else {
      lines.insert("  \(camelCaseComponentName)Component,", at: startOfExportLines + index + 2)
    }
    
    let newFileContent = lines.joined(separator: "\n")
    try newFileContent.write(to: componentsFileURL, atomically: true, encoding: .utf8)
    
    return index
  }
  catch {
    print("Could not add component to config/components.ts. Will not be added to index.html and styles/styles.css either.")
    return -1
  }
}

func addToHtmlTemplates(_ componentPath: String, at index: Int) {
  let componentName = componentPath.split(separator: "/").last!
  let htmlTemplatesFileURL = pcct.projectURL.appendingPathComponent("src/index.html")
  
  do {
    let fileContent = try String(contentsOf: htmlTemplatesFileURL)
    var lines = fileContent.components(separatedBy: .newlines)
    let startOfComponentLines = lines.firstIndex(of: "    <!-- Component templates -->")!
    
    let newRequirePath = "'./components/" + componentPath + "/" + componentName + ".template.html'"
    let newComponentLine = "${require(" + newRequirePath + ")}"
    
    lines.insert("    \(newComponentLine)", at: startOfComponentLines + index + 1)

    let newFileContent = lines.joined(separator: "\n")
    try newFileContent.write(to: htmlTemplatesFileURL, atomically: true, encoding: .utf8)
  }
  catch {
    print("Could not add component to index.html")
  }
}

func addToStyles(_ componentPath: String, at index: Int) {
  let componentName = componentPath.split(separator: "/").last!
  let stylesFileURL = pcct.projectURL.appendingPathComponent("src/styles/main.css")
  
  do {
    let fileContent = try String(contentsOf: stylesFileURL)
    var lines = fileContent.components(separatedBy: .newlines)
    let startOfComponentLines = lines.firstIndex(of: "/* Component styles */")!
    
    let newImportPath = "'../components/" + componentPath + "/" + componentName + ".styles.css'"
    let newComponentLine = "@import " + newImportPath + ";"
    
    lines.insert(newComponentLine, at: startOfComponentLines + index + 1)
    
    let newFileContent = lines.joined(separator: "\n")
    try newFileContent.write(to: stylesFileURL, atomically: true, encoding: .utf8)
  }
  catch {
    print("Could not add component to main.css")
  }
}

func createComponent(_ componentPath: String) {
  let fileManager = FileManager.default
  let componentsDirectoryURL = pcct.projectURL.appendingPathComponent("src/components")
  let newComponentPath: String
  let componentName = componentPath.split(separator: "/").last!
  
  var isDirectory: ObjCBool = false
  if fileManager.fileExists(atPath: componentsDirectoryURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
    newComponentPath = componentsDirectoryURL.path + "/" + componentPath + "/"
    
    if fileManager.fileExists(atPath: newComponentPath + componentName + ".component.ts") {
      print("\(componentPath) already exists.")
    } else {
      do {
        try fileManager.createDirectory(atPath: newComponentPath, withIntermediateDirectories: true)
        
        let componentTemplate = copyTemplate("component-template")
        let htmlTemplate = copyTemplate("html-template")
        
        let specifiedComponentTemplate = replaceName(here: componentTemplate, with: String(componentName))
        let specifiedHtmlTemplate = replaceName(here: htmlTemplate, with: String(componentName))
        
        try specifiedComponentTemplate.write(toFile: newComponentPath + componentName + ".component.ts", atomically: true, encoding: .utf8)
        try specifiedHtmlTemplate.write(toFile: newComponentPath + componentName + ".template.html", atomically: true, encoding: .utf8)
        fileManager.createFile(atPath: newComponentPath + componentName + ".styles.css", contents: nil)
        
        let index = addToComponents(componentPath)
        if index >= 0 {
          addToHtmlTemplates(componentPath, at: index)
          addToStyles(componentPath, at: index)
        }
        
      }
      catch {
        print("Something went wrong.")
      }
    }
  } else {
    print("Could not locate components folder.")
  }
}

func moveComponent(from: String, to: String) {
  let fileManager = FileManager.default
  let componentsDirectoryURL = pcct.projectURL.appendingPathComponent("src/components")
  let componentsFileURL = pcct.projectURL.appendingPathComponent("src/config/components.ts")
  let htmlTemplatesFileURL = pcct.projectURL.appendingPathComponent("src/index.html")
  let stylesFileURL = pcct.projectURL.appendingPathComponent("src/styles/main.css")
  let oldComponentPath = componentsDirectoryURL.path + "/" + from + "/"
  let newComponentPath = componentsDirectoryURL.path + "/" + to + "/"
  
  let oldComponentName = from.split(separator: "/").last!
  let oldComponentNameSplit = oldComponentName.split(separator: "-")
  let oldComponentNameSplitCapped = oldComponentNameSplit.map({ word in word.capitalized  })
  let oldCamelCaseComponentName = oldComponentNameSplitCapped.joined() + "Component"
  
  let newComponentName = to.split(separator: "/").last!
  let newComponentNameSplit = newComponentName.split(separator: "-")
  let newComponentNameSplitCapped = newComponentNameSplit.map({ word in word.capitalized  })
  let newCamelCaseComponentName = newComponentNameSplitCapped.joined() + "Component"
  
  let oldPath = "/components/" + from
  let newPath = "/components/" + to
  
  if fileManager.fileExists(atPath: oldComponentPath) {
    if fileManager.fileExists(atPath: newComponentPath) {
      print("You are trying to move to a component that already exists.")
    } else {
      do {
        // cannot at this point move two to one/two where one is a non-existent directory
        try fileManager.moveItem(atPath: oldComponentPath, toPath: newComponentPath)
        
        // rearrange components
        do {
          let fileContent = try String(contentsOf: componentsFileURL)
          var lines = fileContent.components(separatedBy: .newlines)
          
          var oldComponentIndices = [Int]()
          var newComponentIndices = [Int]()
          
          for (index, line) in lines.enumerated() {
            if line.contains(oldPath) && line.contains(oldCamelCaseComponentName) {
              lines[index] = line.replacingOccurrences(of: oldPath + "/\(oldComponentName).component", with: newPath + "/\(newComponentName).component").replacingOccurrences(of: oldCamelCaseComponentName, with: newCamelCaseComponentName)
              oldComponentIndices.append(index)
            } else if line.contains(oldPath) {
              lines[index] = line.replacingOccurrences(of: oldPath, with: newPath)
              oldComponentIndices.append(index)
            }
          }
          
          let importLines = lines[1..<lines.count].filter({ line in line.hasPrefix("import") })
          let startOfExportLines = lines.firstIndex(of: "export const components: ComponentDefinition[] = [")!
          let endOfExportLines = lines.firstIndex(of: "];")!
          let pathsOfImportLines = importLines.map({ line in line.components(separatedBy: " ")[5] })
          
          func incOrder(_ lineOne: String, _ lineTwo: String) -> Bool {
            var toCompareOne: String!
            var toCompareTwo: String!
            
            for line in pathsOfImportLines {
              if lineOne.contains(line) {
                toCompareOne = line
              }
              if lineTwo.contains(line) {
                toCompareTwo = line
              }
            }
            
            return toCompareOne < toCompareTwo
          }
          
          lines[lines.index(of: importLines.first!)!...lines.index(of: importLines.last!)!].sort(by: { incOrder($0, $1) })
          
          for (index, line) in lines.enumerated() {
            if line.contains(newPath) {
              newComponentIndices.append(index)
            }
          }
          
          var swapArray = [String]()
          for i in 0..<oldComponentIndices.count {
            if lines[startOfExportLines...endOfExportLines - 1][oldComponentIndices[i] + startOfExportLines] == "  \(oldCamelCaseComponentName)," || lines[startOfExportLines...endOfExportLines - 1][oldComponentIndices[i] + startOfExportLines] == "  \(oldCamelCaseComponentName)" {
              swapArray.append("  \(newCamelCaseComponentName),")
            } else {
              swapArray.append(lines[startOfExportLines...endOfExportLines - 1][oldComponentIndices[i] + startOfExportLines])
            }
          }
          swapArray.sort()
          
          lines[startOfExportLines...endOfExportLines - 1].removeSubrange(oldComponentIndices.first! + startOfExportLines...oldComponentIndices.last! + startOfExportLines)
          
          if newComponentIndices.last! + startOfExportLines == endOfExportLines - 1 {
            lines[endOfExportLines - swapArray.count - 1] += ","
            swapArray[swapArray.count - 1] = String(swapArray[swapArray.count - 1][..<swapArray[swapArray.count - 1].index(swapArray[swapArray.count - 1].endIndex, offsetBy: -1)])
          } else if oldComponentIndices.last! + startOfExportLines == endOfExportLines - 1 {
            lines[endOfExportLines - swapArray.count - 1] = String(lines[endOfExportLines - swapArray.count - 1][..<lines[endOfExportLines - swapArray.count - 1].index(lines[endOfExportLines - swapArray.count - 1].endIndex, offsetBy: -1)])
          }
          
          lines.insert(contentsOf: swapArray, at: newComponentIndices.first! + startOfExportLines)
          
          let newFileContent = lines.joined(separator: "\n")
          try newFileContent.write(to: componentsFileURL, atomically: true, encoding: .utf8)
        }
        catch {
          print("Could not rearrange config/components.ts.")
        }
        
        // rearrange HTML
        do {
          let fileContent = try String(contentsOf: htmlTemplatesFileURL)
          var lines = fileContent.components(separatedBy: .newlines)
          let startOfComponentLines = lines.firstIndex(of: "    <!-- Component templates -->")!
          let endOfComponentLines = lines.firstIndex(of: "  </body>")!
          
          for (index, line) in lines.enumerated() {
            if line.contains(oldPath + "/\(oldComponentName).template") {
              lines[index] = line.replacingOccurrences(of: oldPath + "/\(oldComponentName).template", with: newPath + "/\(newComponentName).template")
            } else if line.contains(oldPath) {
              lines[index] = line.replacingOccurrences(of: oldPath, with: newPath)
            }
          }
          
          lines[startOfComponentLines + 1...endOfComponentLines - 1].sort()
          
          let newFileContent = lines.joined(separator: "\n")
          try newFileContent.write(to: htmlTemplatesFileURL, atomically: true, encoding: .utf8)
        }
        catch {
          print("Could not rearrange index.html.")
        }
        
        // rearrange CSS
        do {
          let fileContent = try String(contentsOf: stylesFileURL)
          var lines = fileContent.components(separatedBy: .newlines)
          let startOfComponentLines = lines.firstIndex(of: "/* Component styles */")!
          
          for (index, line) in lines.enumerated() {
            if line.contains(oldPath + "/\(oldComponentName).styles") {
              lines[index] = line.replacingOccurrences(of: oldPath + "/\(oldComponentName).styles", with: newPath + "/\(newComponentName).styles")
            } else if line.contains(oldPath) {
              lines[index] = line.replacingOccurrences(of: oldPath, with: newPath)
            }
          }
          
          lines[startOfComponentLines + 1..<lines.endIndex - 1].sort()
          
          let newFileContent = lines.joined(separator: "\n")
          try newFileContent.write(to: stylesFileURL, atomically: true, encoding: .utf8)
        }
        catch {
          print("Could not rearrange styles/main.css.")
        }
        
        // rename inside component file and file itself
        do {
          try fileManager.moveItem(atPath: newComponentPath + oldComponentName + ".component.ts", toPath: newComponentPath + newComponentName + ".component.ts")
          
          let fileContent = try String(contentsOfFile: newComponentPath + newComponentName + ".component.ts")
          let lines = fileContent.components(separatedBy: .newlines)
          let newLines = lines.map({ line in line.replacingOccurrences(of: oldCamelCaseComponentName, with: newCamelCaseComponentName) })
          let newFileContent = newLines.joined(separator: "\n")
          try newFileContent.write(toFile: newComponentPath + newComponentName + ".component.ts", atomically: true, encoding: .utf8)
        }
        catch {
          print("Could not rename component file name in src/components/\(to)")
        }
        
        // rename inside HTML file and file itself
        do {
          try fileManager.moveItem(atPath: newComponentPath + oldComponentName + ".template.html", toPath: newComponentPath + newComponentName + ".template.html")
          
          let fileContent = try String(contentsOfFile: newComponentPath + newComponentName + ".template.html")
          let lines = fileContent.components(separatedBy: .newlines)
          let newLines = lines.map({ line in line.replacingOccurrences(of: oldCamelCaseComponentName, with: newCamelCaseComponentName) })
          let newFileContent = newLines.joined(separator: "\n")
          try newFileContent.write(toFile: newComponentPath + newComponentName + ".template.html", atomically: true, encoding: .utf8)
        }
        catch {
          print("Could not rename HTML file name in src/components/\(to)")
        }
        
        // rename inside CSS file and file itself
        do {
          try fileManager.moveItem(atPath: newComponentPath + oldComponentName + ".styles.css", toPath: newComponentPath + newComponentName + ".styles.css")
          
          let fileContent = try String(contentsOfFile: newComponentPath + newComponentName + ".styles.css")
          let lines = fileContent.components(separatedBy: .newlines)
          let newLines = lines.map({ line in line.replacingOccurrences(of: "app-" + oldComponentName, with: "app-" + newComponentName) })
          let newFileContent = newLines.joined(separator: "\n")
          try newFileContent.write(toFile: newComponentPath + newComponentName + ".styles.css", atomically: true, encoding: .utf8)
        }
        catch {
          print("Could not rename CSS file name in src/components/\(to)")
        }
        
        print("NOTE: any use of \(String(oldComponentNameSplit.first!.first!) + oldComponentNameSplitCapped.joined().dropFirst()) in other components or HTML files must be manually changed to \(String(newComponentNameSplit.first!.first!) + newComponentNameSplitCapped.joined().dropFirst()) !")
      }
      catch {
        print("Could not move \(oldComponentName) from \(oldComponentPath) to \(newComponentPath)")
      }
    }
  } else {
    print("You are trying to move a component that does not exist.")
  }
}

func deleteComponent(_ componentPath: String) {
  let fileManager = FileManager.default
  let componentsDirectoryURL = pcct.projectURL.appendingPathComponent("src/components")
  let componentsFileURL = pcct.projectURL.appendingPathComponent("src/config/components.ts")
  let htmlTemplatesFileURL = pcct.projectURL.appendingPathComponent("src/index.html")
  let stylesFileURL = pcct.projectURL.appendingPathComponent("src/styles/main.css")
  var importLinesToRemove = [Int]()

  if fileManager.fileExists(atPath: componentsDirectoryURL.path + "/" + componentPath + "/") {
    do {
      // remove from components
      do {
        let fileContent = try String(contentsOf: componentsFileURL)
        let lines = fileContent.components(separatedBy: .newlines)
        
        let startOfExportLines = lines.firstIndex(of: "export const components: ComponentDefinition[] = [")!
        let endOfExportLines = lines.firstIndex(of: "];")!
        
        let needle = "/components/" + componentPath
        let pattern = "\(needle)\\/.*"
        let regex = try NSRegularExpression(pattern: pattern)
        
        for (index, line) in lines.enumerated() {
          let matchesInLine = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
          if matchesInLine.count > 0 {
            importLinesToRemove.append(index)
          }
        }
        let allLinesToRemove = importLinesToRemove + importLinesToRemove.map({ index in index + startOfExportLines })
        let allLinesToKeep = Set(lines.indices).subtracting(allLinesToRemove)
        let newLinesDict = lines.enumerated().filter({ allLinesToKeep.contains($0.0) })
        var newLines = newLinesDict.map({ $0.element })
        let endOfNewExportLines = newLines.firstIndex(of: "];")!
        
        if allLinesToRemove.contains(endOfExportLines - 1 ) {
          newLines[endOfNewExportLines - 1] = String(newLines[endOfNewExportLines - 1][..<newLines[endOfNewExportLines - 1].index(newLines[endOfNewExportLines - 1].endIndex, offsetBy: -1)])
        }
        
        let newFileContent = newLines.joined(separator: "\n")
        try newFileContent.write(to: componentsFileURL, atomically: true, encoding: .utf8)
      }
      catch {
        print("Could not remove component from config/components.ts.")
      }
      
      // remove from HTML
      do {
        let fileContent = try String(contentsOf: htmlTemplatesFileURL)
        let lines = fileContent.components(separatedBy: .newlines)
        
        let startOfComponentLines = lines.firstIndex(of: "    <!-- Component templates -->")!
        
        let allLinesToRemove = importLinesToRemove.map({ index in index + startOfComponentLines })
        let allLinesToKeep = Set(lines.indices).subtracting(allLinesToRemove)
        let newLinesDict = lines.enumerated().filter({ allLinesToKeep.contains($0.0) })
        let newLines = newLinesDict.map({ $0.element })
        
        let newFileContent = newLines.joined(separator: "\n")
        try newFileContent.write(to: htmlTemplatesFileURL, atomically: true, encoding: .utf8)
      }
      catch {
        print("Could not remove component from index.html.")
      }
      
      // remove from CSS
      do {
        let fileContent = try String(contentsOf: stylesFileURL)
        let lines = fileContent.components(separatedBy: .newlines)
        let startOfComponentLines = lines.firstIndex(of: "/* Component styles */")!
        
        let allLinesToRemove = importLinesToRemove.map({ index in index + startOfComponentLines })
        let allLinesToKeep = Set(lines.indices).subtracting(allLinesToRemove)
        let newLinesDict = lines.enumerated().filter({ allLinesToKeep.contains($0.0) })
        let newLines = newLinesDict.map({ $0.element })
        
        let newFileContent = newLines.joined(separator: "\n")
        try newFileContent.write(to: stylesFileURL, atomically: true, encoding: .utf8)
      }
      catch {
        print("Could not remove component from styles/main.css.")
      }
      
//      try fileManager.removeItem(atPath: componentsDirectoryURL.path + "/" + componentPath + "/")
      let wasteURL = URL(fileURLWithPath: componentsDirectoryURL.path + "/" + componentPath + "/")
      try fileManager.trashItem(at: wasteURL, resultingItemURL: nil)
//      print("Successfully removed component at \(componentsDirectoryURL.path + "/" + componentPath + "/")")
    }
    catch {
      print("Was not able to delete component.")
    }
  } else {
    print("You are trying to delete a component that does not exist.")
  }
}


let argumentCount = CommandLine.argc - 1
let arguments = CommandLine.arguments
if arguments.count < 2 {
  print("Supply at least one arguement please.")
  exit(0)
}
let (option, value) = getOption(arguments[1])

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
case .createComponent:
  if argumentCount != 2 {
    if argumentCount > 2 {
      print("Too many arguments for \(option) option. Should have two.")
    } else {
      print("Too few arguments for \(option) option. Should have two.")
    }
  } else {
    createComponent(arguments[2])
  }
case .moveComponent:
  if argumentCount != 3 {
    if argumentCount > 3 {
      print("Too many arguments for \(option) option. Should have three.")
    } else {
      print("Too few arguments for \(option) option. Should have three.")
    }
  } else {
    print("Are you sure you want to move the \(arguments[2]) component to \(arguments[3])? (y/n)")
    let response = readLine()
    if response == "y" {
      moveComponent(from: arguments[2], to: arguments[3])
    } else {
      print("\(arguments[2]) component was not moved to \(arguments[3]).")
    }
  }
case .deleteComponent:
  if argumentCount != 2 {
    if argumentCount > 2 {
      print("Too many arguments for \(option) option. Should have two.")
    } else {
      print("Too few arguments for \(option) option. Should have two.")
    }
  } else {
    print("Are you sure you want to delete the \(arguments[2]) component? (y/n)")
    let response = readLine()
    if response == "y" {
      deleteComponent(arguments[2])
    } else {
      print("\(arguments[2]) component was not deleted.")
    }
  }
case .unspecified: print("You're doing something wrong.")
}
