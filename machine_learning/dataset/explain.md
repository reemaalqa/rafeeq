Description
SauDial: The Saudi Arabic Dialects Game Localization Dataset is a curated collection of parallel text samples designed for video game localization. It features content in English, Modern Standard Arabic (MSA), and four major Saudi dialects: Najdi, Hijazi, Janoubi, and Eastern. The dataset was initially generated using the OpenAI GPT-4o model and refined with pre-compiled dialect-specific resources.

Each entry in the dataset includes:
- Original English text
- MSA translation
- Dialectal translation
- Game context and age rating information
- Linguistic notes on dialect features

The content covers various game genres, scenario types, tones, and age ratings, making it versatile for different game development needs. The dataset underwent thorough cleaning and editing to ensure dialectal accuracy, tonal appropriateness, and cultural fidelity.

This resource is valuable for:
- Game developers and localization teams
- Researchers in translation, cultural, localization, and game studies
- Training and fine-tuning Large Language Models (LLMs)
- Educational purposes in translation and localization studies
- Professional translators and localizers as a specialized translation memory (TM)

The dataset aims to streamline game localization processes and enhance the authenticity of Arabic language representation in video games, particularly for the Saudi market.

Download All 320 KB

Files

xlsx
SauDial Dataset.xlsx
316 KB

py
saudial_generator.py
25 KB
Steps to reproduce
Steps to reproduce the SauDial dataset:

Setup:

Install required Python libraries: openai, pandas, openpyxl, tenacity
Obtain an API key from OpenAI for GPT-4o access


Data Generation:

Initialize the SaudiDialectGameLocalizationGenerator class
Define parameters:

Scenario types (e.g., epic battle, marketplace haggling)
Dialects (Najdi, Hijazi, Janoubi, Eastern)
Game types (e.g., RPG, Adventure, Platformer)
Tones (e.g., Serious, Humorous, Whimsical)
Age ratings (3+, 7+, 12+, 16+, 18+)




API Interaction:

Generate dynamic prompts combining the above parameters
Send prompts to GPT-4o API
Retrieve responses containing English text, MSA translation, dialect translation, context explanations, and dialect notes


Data Processing:

Parse API responses
Assign localization difficulty and target audience
Apply content uniqueness checks
Highlight dialect-specific words


Data Compilation:

Organize processed data into a pandas DataFrame
Export data to an Excel spreadsheet using openpyxl


Post-Processing:

Manual review and refinement of generated content
Ensure dialectal accuracy and cultural appropriateness
Verify tonal consistency and age-rating adherence


Quality Assurance:

Conduct linguistic validation by native speakers
Cross-check cultural references and idiomatic expressions


Final Dataset Preparation:

Compile refined entries into the final dataset format
Add metadata and usage instructions



Note: The exact reproduction of the dataset may vary due to the non-deterministic nature of language model outputs and the manual refinement process.

Categories
Natural Language Processing, Machine Translation, Corpus-Based Translation Studies