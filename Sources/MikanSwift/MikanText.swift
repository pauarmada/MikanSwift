//
//  MikanText.swift
//  MikanSwift
//
//  Created by pauarmada on 2024/09/07.
//

import SwiftUI

public struct MikanText: View {
    public let text: String
    public let alignment: TextAlignment
    
    public init(_ text: String, alignment: TextAlignment = .leading) {
        self.text = text
        self.alignment = alignment
    }
    
    public var body: some View {
        // Split the given text using the mikan.js logic
        let split = MikanJs.split(text)
        
        // Wrap the split text inside the container that will handle the layout
        TextLayout(alignment: alignment) {
            // Actual split text to be layouted
            ForEach(split, id: \.self) { item in
                Text(item)
                    .fixedSize()
            }
            
            // Add views to serve as text size guides.
            // If a token ends with 、or 。, e.g.: "常に最新、", the `sizeThatFits` call
            // on this text will result in a smaller frame. meaning, the next text will not
            // get the proper spacing. To combat this, we use the size of the text
            // where the 、or 。is in front. See `TextLayout.makeCache`.
            ForEach(split, id: \.self) { item in
                Text(String(item.sorted()))
                    .fixedSize()
                    .hidden()
            }
            
            // To compute the line height and line spacing without knowing the Font, we
            // introduce two hidden views that we will know have 1 and 2 lines respectively.
            // See `TextLayout.makeCache`.
            Text("てん").hidden()
            Text("て\n").hidden()
        }
        .clipped()
    }
    
    private struct TextLayout: Layout {
        let alignment: TextAlignment
        
        struct Cache {
            let count: Int
            let sizes: [CGSize]
            let lineHeight: CGFloat
            let lineSpacing: CGFloat
        }
        
        struct RowInfo {
            let width: CGFloat
            let indices: [Int]
        }
        
        func makeCache(subviews: Subviews) -> Cache {
            // Pull up the extra views used for line height/spacing computation
            let extraViews = subviews.suffix(2)
            let singleLiner = extraViews[0].sizeThatFits(.unspecified)
            let twoLiner = extraViews[1].sizeThatFits(.unspecified)
            
            // Half the rest of the items and we get the count of the actual tokens
            let count = (subviews.count - extraViews.count) / 2
            
            // Get all the subviews and its corresponding guide
            // The size to be assigned to the subview will be whichever is larger
            let sizes = subviews
                .prefix(count)
                .indices
                .map { index -> CGSize in
                    let size1 = subviews[index].sizeThatFits(.unspecified)
                    let size2 = subviews[index + count].sizeThatFits(.unspecified)
                    return CGSize(
                        width: max(size1.width, size2.width),
                        height: max(size1.height, size2.height)
                    )
                }
            
            return Cache(
                count: count,
                sizes: sizes,
                lineHeight: singleLiner.height,
                lineSpacing: twoLiner.height - singleLiner.height * 2
            )
        }
        
        private func analyzeRows(proposalWidth: CGFloat, cache: Cache) -> [RowInfo] {
            var indices: [Int] = []
            var x: CGFloat = 0
            
            var rows: [RowInfo] = []
            
            (0 ..< cache.count).forEach { index in
                let size = cache.sizes[index]
                
                let isNewLine = size.width == 0
                let willNotFit = x + size.width > proposalWidth
                
                if isNewLine || willNotFit {
                    // append the new line
                    rows.append(RowInfo(width: x, indices: indices))
                    
                    // reset the width
                    x = 0
                    indices = []
                }
                
                // place view
                x += size.width
                indices.append(index)
            }
            
            // Register the running width and indices
            rows.append(RowInfo(width: x, indices: indices))
            
            return rows
        }
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
            let proposalWidth = proposal.width ?? .zero
            let rows = analyzeRows(proposalWidth: proposalWidth, cache: cache)
            
            // The width of the view is the lesser of the maximum row width
            // vs the proposed width
            let maxRowWidth = rows.map { $0.width }.max() ?? 0
            let width = min(proposalWidth, maxRowWidth + 0.1)
            
            // Height is the number of lines with line spaces in between
            let lineCount = CGFloat(rows.count)
            let height = lineCount * cache.lineHeight + (lineCount - 1) * cache.lineSpacing
            
            return CGSize(width: width, height: height)
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
            let proposalWidth = proposal.width ?? .zero
            let rows = analyzeRows(proposalWidth: proposalWidth, cache: cache)
            
            // Go through each row
            var x = CGFloat.zero
            var y = CGFloat.zero
            rows.forEach { row in
                
                // Begin placing values depending on the alignment
                switch alignment {
                case .leading:
                    x = .zero
                case .trailing:
                    x = proposalWidth - row.width
                case .center:
                    x = (proposalWidth / 2 - row.width / 2)
                }
                
                // Go through the indices one by one
                row.indices.forEach { index in
                    subviews[index].place(
                        at: CGPoint(
                            x: bounds.minX + x,
                            y: bounds.minY + y
                        ),
                        proposal: proposal
                    )
                    x += cache.sizes[index].width
                }
                y += cache.lineHeight + cache.lineSpacing
            }
        }
    }
}

#Preview {
    struct TestContent: Hashable {
        let text: String
        let containerWidth: CGFloat
    }
    
    struct ContainerView: View {
        @State var sliderValue = CGFloat(180)
        @State var selectedTab = TextAlignment.leading
        
        let content = TestContent(
            text: "常に最新、最高のモバイル。Androidを開発した同じチームから",
            containerWidth: .infinity
        )
        
        let tabs = [TextAlignment.leading, .center, .trailing]
        
        var body: some View {
            VStack {
                HStack {
                    Text("Container Width (\(Int(sliderValue)))")
                        .frame(width: 180)
                    Slider(value: $sliderValue, in: 2...180, step: 4)
                        .frame(width: 160)
                }
                
                
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: {
                            withAnimation {
                                selectedTab = tab
                            }
                        }, label: {
                            VStack(spacing: 0) {
                                Text("\(tab)")
                                    .frame(width: 80)
                                Rectangle().fill(selectedTab == tab ? Color.black : Color.clear)
                                    .frame(height: 1)
                            }.fixedSize()
                        })
                        .buttonStyle(.plain)
                    }
                }
                Divider().padding(.bottom, 16)
                
                HStack {
                    ZStack {
                        Text(content.text)
                            .multilineTextAlignment(selectedTab)
                            .border(.red)
                    }
                    .frame(width: sliderValue)
                    .background(.yellow)
                    .frame(maxWidth: .infinity)

                    ZStack {
                        MikanText(content.text, alignment: selectedTab)
                            .border(.blue)
                    }
                    .frame(width: sliderValue)
                    .background(.green)
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
        }
    }
    
    return ContainerView()
}
