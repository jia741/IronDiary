import json
import random
from datetime import datetime, timedelta

# Read default exercises
with open('assets/default_exercises.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

categories = data['categories']

random.seed(42)

# Start date: one year ago from today
end_date = datetime.now().date()
start_date = end_date - timedelta(days=365)

records = []
current_date = start_date

while current_date <= end_date:
    # Select number of categories 1-2
    chosen_categories = random.sample(categories, k=random.randint(1, 2))
    # Gather exercises from chosen categories
    exercise_pool = []
    for cat in chosen_categories:
        for ex in cat['exercises']:
            exercise_pool.append({'category': cat['name'], 'exercise': ex})
    # Select 3-5 exercises from the pool (ensure not more than available)
    num_exercises = random.randint(3, min(5, len(exercise_pool)))
    chosen_exercises = random.sample(exercise_pool, k=num_exercises)

    day_records = []
    for item in chosen_exercises:
        reps = random.randint(5, 15)
        weight = round(random.uniform(10, 100), 1)
        rest = random.choice([60, 90, 120])
        day_records.append({
            'category': item['category'],
            'exercise': item['exercise'],
            'reps': reps,
            'weight': weight,
            'unit': 'kg',
            'rest_seconds': rest
        })

    records.append({
        'date': current_date.isoformat(),
        'workouts': day_records
    })

    # Advance by 0-3 days
    current_date += timedelta(days=random.randint(0, 3) or 1)

output = {'records': records}

with open('assets/test_records.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

