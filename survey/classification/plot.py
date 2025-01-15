import json
import matplotlib.pyplot as plt
import numpy as np
from collections import defaultdict


def plot_stacked_column(datasets, key="category"):
    category_counts = defaultdict(lambda: {name: 0 for name in datasets.keys()})

    for dataset_name, dataset_points in datasets.items():
        for data_point in dataset_points:
            category = data_point.get(key, "None")
            category_counts[category][dataset_name] += 1

    bottom = np.zeros(len(datasets))
    dataset_names = list(datasets.keys())

    for category, counts in category_counts.items():
        count_values = [counts[dataset_name] for dataset_name in dataset_names]

        bars = plt.bar(
            dataset_names,
            [np.nan if x == 0 else x for x in count_values],
            bottom=bottom,
            label=category,
            edgecolor="black",
        )

        plt.bar_label(bars, label_type="center")

        bottom += np.array(count_values)

    plt.xlabel(key.capitalize())
    plt.ylabel("No. Bugs")
    plt.legend()
    plt.title(f"Bugs by {key.capitalize()}")
    plt.savefig(f"{key}.png")


if __name__ == "__main__":
    with open("natural.json", "r") as file:
        data = json.load(file)
    plot_stacked_column(data)
