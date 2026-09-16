import { User } from './user.entity';
import { UserPreferences } from './user-preferences.entity';
import { Ingredient } from './ingredient.entity';
import { PantryItem } from './pantry-item.entity';
import { Recipe } from './recipe.entity';
import { RecipeIngredient } from './recipe-ingredient.entity';
import { RecipeStep } from './recipe-step.entity';
import { Like } from './like.entity';
import { Comment } from './comment.entity';
import { SavedRecipe } from './saved-recipe.entity';

export const entities = [
  User,
  UserPreferences,
  Ingredient,
  PantryItem,
  Recipe,
  RecipeIngredient,
  RecipeStep,
  Like,
  Comment,
  SavedRecipe,
];

export {
  User,
  UserPreferences,
  Ingredient,
  PantryItem,
  Recipe,
  RecipeIngredient,
  RecipeStep,
  Like,
  Comment,
  SavedRecipe,
};
