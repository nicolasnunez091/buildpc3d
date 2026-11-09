import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

client = Groq(api_key=os.getenv("GROQ_API_KEY", "TU_API_KEY_AQUI"))

@app.route('/analyze-usage', methods=['POST'])
def analyze_usage():
    data = request.get_json()
    user_prompt = data.get('prompt', '')

    if not user_prompt:
        return jsonify({"error": "No se proporcionó ningún texto"}), 400

    try:
        system_instruction = (
            "Eres un asistente de hardware. Analiza la necesidad del usuario y responde "
            "ÚNICAMENTE con una de estas tres palabras claves sin añadir punto ni texto extra: "
            "Gamer, Oficina, o Edicion."
        )

        chat_completion = client.chat.completions.create(
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": user_prompt}
            ],
            model="llama-3.1-8b-instant",
            temperature=0.2
        )

        usage_profile = chat_completion.choices[0].message.content.strip()

        return jsonify({
            "status": "success",
            "usage_profile": usage_profile
        })

    except Exception as e:
        return jsonify({
            "status": "fallback",
            "message": "Fallo en el servicio de IA, usar selección manual",
            "error": str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
