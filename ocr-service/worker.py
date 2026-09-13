import os

# Must be set BEFORE importing PaddleOCR
os.environ["FLAGS_use_mkldnn"] = "0"
os.environ["FLAGS_enable_pir_api"] = "0"

from pathlib import Path

from fastapi import FastAPI, File, UploadFile
from paddleocr import PaddleOCR


app = FastAPI(title="Pramana Kosha OCR Service")


ocr = PaddleOCR(
    lang=os.getenv("PADDLEOCR_LANG", "en"),
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
    enable_mkldnn=False,
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/ocr")
async def extract_text(file: UploadFile = File(...)) -> dict[str, str]:
    input_path = (
        Path("/tmp")
        / f"pramana-ocr-{os.getpid()}-{file.filename or 'document.jpg'}"
    )

    try:
        input_path.write_bytes(await file.read())

        results = ocr.predict(str(input_path))

        texts: list[str] = []

        for result in results:
            data = result.json if hasattr(result, "json") else {}

            if callable(data):
                data = data()

            if isinstance(data, dict):
             result_data = data.get("res", data)

        if isinstance(result_data, dict):
         texts.extend(
            str(value)
            for value in result_data.get("rec_texts", [])
            if value
        )

        return {
            "text": "\n".join(texts),
            "provider": "paddleocr",
        }

    finally:
        input_path.unlink(missing_ok=True)