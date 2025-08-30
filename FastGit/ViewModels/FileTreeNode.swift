//
//  FileTreeNode.swift
//  FastGit
//
//  Created by 朱晨 on 2025/8/30.
//

import Foundation
import SwiftUI

/// A node in the file tree, representing either a folder or a file.
/// 文件树中的一个节点，可以代表一个文件夹或一个文件。
class FileTreeNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    let file: GitFileStatus? // If nil, this node is a folder.
    var children: [FileTreeNode] = []
    
    @Published var isExpanded: Bool = false

    init(name: String, path: String, file: GitFileStatus? = nil) {
        self.name = name
        self.path = path
        self.file = file
    }

    /// Recursively adds a child node based on path components.
    private func addChild(file: GitFileStatus, components: [String]) {
        guard let firstComponent = components.first else {
            return
        }
        
        let remainingComponents = Array(components.dropFirst())

        if remainingComponents.isEmpty {
            // This is the file node
            let newPath = (self.path == ".") ? firstComponent : "\(self.path)/\(firstComponent)"
            let childNode = FileTreeNode(name: firstComponent, path: newPath, file: file)
            children.append(childNode)
        } else {
            // This is a folder node
            let newFolderPath = (self.path == ".") ? firstComponent : "\(self.path)/\(firstComponent)"
            if let existingChild = children.first(where: { $0.name == firstComponent && $0.file == nil }) {
                existingChild.addChild(file: file, components: remainingComponents)
            } else {
                let newFolderNode = FileTreeNode(name: firstComponent, path: newFolderPath)
                newFolderNode.isExpanded = true // Auto-expand folders by default
                newFolderNode.addChild(file: file, components: remainingComponents)
                children.append(newFolderNode)
            }
        }
    }
    
    /// Sorts children: folders first, then files, all alphabetically.
    func sort() {
        children.sort {
            if $0.file == nil && $1.file != nil { return true }
            if $0.file != nil && $1.file == nil { return false }
            return $0.name.lowercased() < $1.name.lowercased()
        }
        children.forEach { $0.sort() }
    }
    
    /// Toggles the expanded state for this node and all its children recursively.
    func toggleExpansion(shouldExpand: Bool) {
        if self.file == nil { // Only folders can be expanded
            self.isExpanded = shouldExpand
            for child in children {
                child.toggleExpansion(shouldExpand: shouldExpand)
            }
        }
    }

    /// Builds a tree structure from a flat list of files.
    static func buildTree(from files: [GitFileStatus]) -> [FileTreeNode] {
        let rootNode = FileTreeNode(name: "root", path: ".")
        
        for file in files {
            let components = file.path.split(separator: "/").map(String.init)
            rootNode.addChild(file: file, components: components)
        }
        
        rootNode.sort()
        return rootNode.children
    }
}
