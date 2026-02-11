import SwiftUI
import Combine

/// Sheet for clinicians to enter or update a patient's resting heart rate
struct RestingHREditorSheet: View {
    @ObservedObject var viewModel: PatientDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var bpmInput: String
    @State private var didAttemptSave = false

    init(viewModel: PatientDetailViewModel) {
        self.viewModel = viewModel
        let current = viewModel.patientDetail?.profile.restingHeartRate
        _bpmInput = State(initialValue: current.map { String(format: "%.0f", $0) } ?? "")
    }

    private var isValid: Bool {
        PatientDetailViewModel.isValidBPM(bpmInput)
    }

    private var showError: Bool {
        !bpmInput.isEmpty && !isValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("BPM (30–220)", text: $bpmInput)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Resting heart rate in BPM")

                    if showError {
                        Text("Enter a value between 30 and 220")
                            .font(.appCaption)
                            .foregroundColor(.statusRed)
                    }
                } header: {
                    Text("Resting Heart Rate")
                }

                if let errorMsg = viewModel.error, didAttemptSave {
                    Section {
                        Text(errorMsg)
                            .font(.appCaption)
                            .foregroundColor(.statusRed)
                    }
                }
            }
            .navigationTitle("Edit Resting HR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSavingRestingHR {
                        ProgressView()
                    } else {
                        Button("Save") {
                            didAttemptSave = true
                            Task {
                                await viewModel.saveRestingHeartRate(bpmInput)
                                if viewModel.error == nil {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!isValid || viewModel.isSavingRestingHR)
                    }
                }
            }
        }
    }
}
