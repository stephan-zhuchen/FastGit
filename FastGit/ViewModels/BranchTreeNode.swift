import Foundation
import SwiftUI

/// A node in the branch tree, representing either a folder or a branch.
/// 分支树中的一个节点，可以代表一个文件夹或一个分支。
class BranchTreeNode: Identifiable, ObservableObject {
    let id = UUID()
    var name: String
    var branch: GitBranch? // If nil, this node is a folder. 如果为nil，则此节点是文件夹。
    var children: [BranchTreeNode] = []
    
    // ** MODIFICATION: Default state is now collapsed **
    // ** 修改：默认状态现在是折叠的 **
    @Published var isExpanded: Bool = false

    init(name: String, branch: GitBranch? = nil) {
        self.name = name
        self.branch = branch
    }

    /// Toggles the expanded state of the node.
    /// 切换节点的展开/折叠状态。
    func toggleExpanded() {
        guard branch == nil else { return } // Only folders can be expanded
        isExpanded.toggle()
    }

    /// Recursively adds a child node based on path components.
    /// 根据路径组件递归地添加子节点。
    private func addChild(branch: GitBranch, components: [String]) {
        guard let firstComponent = components.first else {
            // Should not happen if called correctly
            return
        }
        
        let remainingComponents = Array(components.dropFirst())

        if remainingComponents.isEmpty {
            // This is the final branch node
            let childNode = BranchTreeNode(name: firstComponent, branch: branch)
            children.append(childNode)
        } else {
            // This is a folder path, find or create the folder node
            if let existingChild = children.first(where: { $0.name == firstComponent && $0.branch == nil }) {
                existingChild.addChild(branch: branch, components: remainingComponents)
            } else {
                let newFolderNode = BranchTreeNode(name: firstComponent)
                newFolderNode.addChild(branch: branch, components: remainingComponents)
                children.append(newFolderNode)
            }
        }
    }
    
    /// Sorts children: folders first, then branches, all alphabetically.
    /// 对子节点进行排序：文件夹优先，然后是分支，都按字母顺序排列。
    func sort() {
        children.sort {
            if $0.branch == nil && $1.branch != nil { return true } // Folder vs Branch
            if $0.branch != nil && $1.branch == nil { return false } // Branch vs Folder
            return $0.name.lowercased() < $1.name.lowercased() // Same type, sort by name
        }
        // Recursively sort children
        children.forEach { $0.sort() }
    }

    /// Builds a tree structure from a flat list of branches.
    /// 从一个扁平的分支列表中构建树状结构。
    static func buildTree(from branches: [GitBranch]) -> [BranchTreeNode] {
        let rootNode = BranchTreeNode(name: "root")
        
        for branch in branches {
            let components = branch.shortName.split(separator: "/").map(String.init)
            rootNode.addChild(branch: branch, components: components)
        }
        
        rootNode.sort()
        return rootNode.children
    }
}

