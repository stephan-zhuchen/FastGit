//
//  SharedViews.swift
//  FastGit
//
//  Created by 朱晨 on 2025/8/30.
//


import SwiftUI

// MARK: - Custom Search Bar Component (Shared)
// 自定义搜索栏组件（共享）
struct CustomSearchBar: View {
    @Binding var searchText: String
    @Binding var isCaseSensitive: Bool
    @Binding var isWholeWord: Bool

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 6)

            TextField("搜索...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)

            HStack(spacing: 2) {
                SearchOptionButton(
                    isOn: $isCaseSensitive,
                    iconName: "textformat.size.larger",
                    tooltip: "大小写敏感"
                )
                SearchOptionButton(
                    isOn: $isWholeWord,
                    iconName: "text.word.spacing",
                    tooltip: "全字匹配"
                )
            }
            .padding(.trailing, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Search Option Button (Shared)
// 搜索选项按钮（共享）
struct SearchOptionButton: View {
    @Binding var isOn: Bool
    let iconName: String
    let tooltip: String

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .symbolVariant(isOn ? .fill : .none)
                .foregroundColor(isOn ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 20, height: 20)
        .background(isOn ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(tooltip)
    }
}
