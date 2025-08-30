import Foundation
import SwiftUI

/// A node in the branch tree, representing either a folder or a branch.
/// 分支树中的一个节点，可以代表一个文件夹或一个分支。
class BranchTreeNode: Identifiable, ObservableObject {
    let id = UUID()
    var name: String
    var branch: GitBranch? // If nil, this node is a folder. 如果为nil，则此节点是文件夹。
    var children: [BranchTreeNode] = []
    
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
            return
        }
        
        let remainingComponents = Array(components.dropFirst())

        if remainingComponents.isEmpty {
            let childNode = BranchTreeNode(name: firstComponent, branch: branch)
            children.append(childNode)
        } else {
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
            if $0.branch == nil && $1.branch != nil { return true }
            if $0.branch != nil && $1.branch == nil { return false }
            return $0.name.lowercased() < $1.name.lowercased()
        }
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

    // ** MODIFIED: Updated filterTree to accept a generic matching closure **
    // ** 修改：更新 filterTree 以接受一个通用的匹配闭包 **
    static func filterTree(
        _ nodes: [BranchTreeNode],
        with searchText: String,
        checkMatch: (String, String) -> Bool
    ) -> [BranchTreeNode] {
        if searchText.isEmpty {
            return nodes
        }
        
        var filteredNodes: [BranchTreeNode] = []
        
        for node in nodes {
            if let branch = node.branch {
                if checkMatch(branch.name, searchText) {
                    filteredNodes.append(node)
                }
            }
            else {
                let filteredChildren = filterTree(node.children, with: searchText, checkMatch: checkMatch)
                if !filteredChildren.isEmpty {
                    let folderCopy = BranchTreeNode(name: node.name)
                    folderCopy.children = filteredChildren
                    folderCopy.isExpanded = true
                    filteredNodes.append(folderCopy)
                }
            }
        }
        
        return filteredNodes
    }
}

