import { useRef, useState } from 'react';
import { Button, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  DigitalInkCanvasView,
  type DigitalInkCanvasHandle,
  downloadModel,
  deleteModel,
  isModelDownloaded,
  listAvailableModels,
  recognize,
  registerCustomModel,
  type RecognitionResult,
} from '@goaid/react-native-mlkit-digital-ink';

const LANGUAGE_TAG = 'en';
const CUSTOM_MODEL_ID = 'stub';

export default function App() {
  const canvasRef = useRef<DigitalInkCanvasHandle>(null);
  const [log, setLog] = useState<string[]>([]);
  const [strokeCount, setStrokeCount] = useState(0);

  const appendLog = (line: string) =>
    setLog((prev) => [line, ...prev].slice(0, 20));

  const runGuarded = async (label: string, action: () => Promise<void>) => {
    try {
      await action();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      appendLog(`${label} FAILED: ${message}`);
    }
  };

  return (
    <View style={styles.container}>
      <DigitalInkCanvasView
        ref={canvasRef}
        style={styles.canvas}
        strokeColor="#1a1a2e"
        strokeWidth={3}
        onCanvasChange={(payload) => setStrokeCount(payload.strokeCount)}
      />
      <Text style={styles.status}>Strokes: {strokeCount}</Text>

      <ScrollView contentContainerStyle={styles.buttonRow} horizontal>
        <Button title="Clear" onPress={() => canvasRef.current?.clear()} />
        <Button title="Undo" onPress={() => canvasRef.current?.undo()} />
        <Button
          title="List models"
          onPress={() =>
            runGuarded('listAvailableModels', async () => {
              const models = await listAvailableModels();
              appendLog(
                `Models: ${models.length} (en downloaded: ${models.find((m) => m.languageTag === LANGUAGE_TAG)?.isDownloaded})`
              );
            })
          }
        />
        <Button
          title="Download en"
          onPress={() =>
            runGuarded('downloadModel', async () => {
              await downloadModel(LANGUAGE_TAG);
              appendLog('Downloaded en model');
            })
          }
        />
        <Button
          title="Delete en"
          onPress={() =>
            runGuarded('deleteModel', async () => {
              await deleteModel(LANGUAGE_TAG);
              appendLog('Deleted en model');
            })
          }
        />
        <Button
          title="Recognize (ML Kit)"
          onPress={() =>
            runGuarded('recognize-mlkit', async () => {
              const downloaded = await isModelDownloaded(LANGUAGE_TAG);
              if (!downloaded) {
                appendLog(
                  'en model not downloaded yet — tap "Download en" first'
                );
                return;
              }
              const ink = await canvasRef.current?.getInk();
              if (!ink) return;
              const result: RecognitionResult = await recognize(ink, {
                kind: 'mlkit',
                languageTag: LANGUAGE_TAG,
              });
              appendLog(
                `ML Kit: ${result.candidates.map((c) => `${c.text} (${c.score.toFixed(2)})`).join(', ')}`
              );
            })
          }
        />
        <Button
          title="Register stub custom model"
          onPress={() =>
            runGuarded('registerCustomModel', async () => {
              await registerCustomModel({
                modelId: CUSTOM_MODEL_ID,
                modelPath: '/data/local/tmp/stub_model.tflite',
                tensorSpec: {
                  inputShape: [1, 64, 64, 1],
                  outputShape: [1, 10],
                  preprocessing: 'rasterize',
                  normalizePoints: true,
                },
              });
              appendLog('Registered stub custom model');
            })
          }
        />
        <Button
          title="Recognize (custom)"
          onPress={() =>
            runGuarded('recognize-custom', async () => {
              const ink = await canvasRef.current?.getInk();
              if (!ink) return;
              const result = await recognize(ink, {
                kind: 'custom',
                modelId: CUSTOM_MODEL_ID,
              });
              appendLog(
                `Custom: ${result.candidates.map((c) => `${c.text} (${c.score.toFixed(2)})`).join(', ')}`
              );
            })
          }
        />
      </ScrollView>

      <ScrollView style={styles.logBox}>
        {log.map((line, index) => (
          <Text key={index} style={styles.logLine}>
            {line}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 48,
  },
  canvas: {
    height: 220,
    marginHorizontal: 16,
    borderWidth: 1,
    borderColor: '#ccc',
    backgroundColor: '#fff',
  },
  status: {
    marginHorizontal: 16,
    marginTop: 8,
  },
  buttonRow: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 8,
  },
  logBox: {
    flex: 1,
    marginHorizontal: 16,
    marginBottom: 16,
  },
  logLine: {
    fontSize: 12,
    marginBottom: 4,
  },
});
