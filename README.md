# Meal Planning and Food Inventory Tracking

This project was developed as part of my Master's thesis at the University of Zagreb, Faculty of Electrical Engineering and Computing (FER).

The project is an Android application designed to simplify meal planning and food inventory management. It allows users to keep track of available ingredients, plan daily meals, manage shopping lists, and receive recipe recommendations based on their preferences and available food.

## Features

* Food inventory management
* Meal planning
* Shopping list creation
* Recipe management and recommendations
* Tracking ingredient quantities and expiration dates
* User-specific recommendations
* Comparison of heuristic and machine learning recommendation approaches

## Recommendation System

The application implements two approaches for recommending recipes:

* **Heuristic approach** – ranks recipes using predefined weights based on factors such as available ingredients, expiration dates, preparation time, and previous user behaviour.
* **Machine learning approach** – uses a logistic regression model trained on user interaction data to calculate recipe recommendation scores.

The two approaches were compared as part of the Master's thesis to evaluate the similarity and differences between their recommendations.

## Technologies

* Flutter
* Dart
* Microsoft SQL Server
* Python
* scikit-learn
* pandas
* Git

## Testing

The application includes unit and widget tests for testing its main functionality.

## Author

**Ivan Samardžić**
Master's Degree in Computing
University of Zagreb – Faculty of Electrical Engineering and Computing (FER)
