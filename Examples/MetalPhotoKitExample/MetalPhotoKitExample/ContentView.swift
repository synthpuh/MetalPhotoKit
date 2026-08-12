//
//  ContentView.swift
//  MetalPhotoKitExample
//
//  Created by Olga on 22.07.2026.
//

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
                imagePreview
                filterPicker
                parameterSliders
                photosPickerButton
            }
            .padding()
            .navigationTitle("MetalPhotoKit")
        }
    }

    private var imagePreview: some View {
        Image(uiImage: isShowingOriginal ? viewModel.sourceImage : (viewModel.filteredImage ?? viewModel.sourceImage))
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilterID) {
            ForEach(DemoFilterCatalog.all) { descriptor in
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
            }
            ForEach(Array(viewModel.selectedFilter.parameters.enumerated()), id: \.offset) { index, parameter in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(parameter.name): \(viewModel.parameterValues[index], specifier: "%.2f")")
                        .font(.caption)
                        .monospacedDigit()
                    Slider(value: $viewModel.parameterValues[index], in: parameter.range)
                }
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
