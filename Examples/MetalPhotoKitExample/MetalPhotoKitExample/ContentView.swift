//
//  ContentView.swift
//  MetalPhotoKitExample
//
//  Created by Olga on 22.07.2026.
//

import MetalPhotoKit
import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentView.makeViewModel()

    var body: some View {
        if let viewModel {
            FilterDemoView(viewModel: viewModel)
        } else {
            ContentUnavailableView(
                "Metal Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("This device doesn't support the Metal features MetalPhotoKit needs.")
            )
        }
    }

    private static func makeViewModel() -> FilterDemoViewModel? {
        guard let sample = UIImage(named: "SamplePhoto") else { return nil }
        return FilterDemoViewModel(sourceImage: sample)
    }
}

private struct FilterDemoView: View {
    @Bindable var viewModel: FilterDemoViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingOriginal = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                renderModePicker
                filterPicker
                parameterSliders
                photosPickerButton
            }
            .padding()
            .navigationTitle("MetalPhotoKit")
        }
    }

    private var preview: some View {
        Group {
            switch viewModel.renderMode {
            case .readback:
                readbackPreview
            case .live:
                livePreview
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red, in: RoundedRectangle(cornerRadius: 8))
                    .padding(8)
            }
        }
    }

    /// `FilterChain.run` into a CPU-readable texture, read back into a
    /// `UIImage`, and displayed by a plain SwiftUI `Image` — supports the
    /// press-and-hold compare gesture since it's just swapping which
    /// already-decoded image is on screen.
    private var readbackPreview: some View {
        Image(uiImage: isShowingOriginal ? viewModel.sourceImage : (viewModel.filteredImage ?? viewModel.sourceImage))
            .resizable()
            .scaledToFit()
            .overlay(alignment: .topTrailing) {
                if viewModel.isProcessing {
                    ProgressView()
                        .padding(10)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isShowingOriginal = true }
                    .onEnded { _ in isShowingOriginal = false }
            )
    }

    /// `FilterChainMetalView`, an `MTKView` the chain renders straight into
    /// — no `filteredImage`, no readback, no compare gesture.
    private var livePreview: some View {
        FilterChainMetalView(
            context: viewModel.context,
            sourceTexture: viewModel.sourceTexture,
            filters: viewModel.currentFilters,
            onError: viewModel.reportLiveRenderError
        )
        .aspectRatio(viewModel.sourceImage.size, contentMode: .fit)
    }

    private var renderModePicker: some View {
        Picker("Render Mode", selection: $viewModel.renderMode) {
            ForEach(RenderMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilterID) {
            ForEach(viewModel.filterCatalog) { descriptor in
                Text(descriptor.title).tag(descriptor.id)
            }
        }
        .pickerStyle(.segmented)
    }

    private var parameterSliders: some View {
        VStack(spacing: 12) {
            HStack {
                Text(viewModel.selectedFilter.title)
                    .font(.headline)
                Spacer()
                Button("Reset", action: viewModel.resetParameters)
                    .font(.caption)
                Button("Reset All", action: viewModel.resetAll)
                    .font(.caption)
            }
            ForEach(Array(viewModel.selectedFilter.parameters.enumerated()), id: \.offset) { index, parameter in
                parameterControl(for: parameter, index: index)
            }
        }
    }

    @ViewBuilder
    private func parameterControl(for parameter: DemoFilterParameter, index: Int) -> some View {
        switch parameter.kind {
        case .continuous(let range):
            VStack(alignment: .leading, spacing: 4) {
                Text("\(parameter.name): \(viewModel.parameterValues[index], specifier: "%.2f")")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: $viewModel.parameterValues[index], in: range)
            }
        case .choice(let options):
            VStack(alignment: .leading, spacing: 4) {
                Text(parameter.name)
                    .font(.caption)
                Picker(parameter.name, selection: Binding(
                    get: { Int(viewModel.parameterValues[index].rounded()) },
                    set: { viewModel.parameterValues[index] = Float($0) }
                )) {
                    ForEach(options.indices, id: \.self) { optionIndex in
                        Text(options[optionIndex]).tag(optionIndex)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var photosPickerButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard
                    let newItem,
                    let data = try? await newItem.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                else { return }
                viewModel.sourceImage = image
            }
        }
    }
}

#Preview {
    ContentView()
}
