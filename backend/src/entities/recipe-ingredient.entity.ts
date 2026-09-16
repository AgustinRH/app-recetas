import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Recipe } from './recipe.entity';
import { Ingredient } from './ingredient.entity';

@Entity('recipe_ingredients')
export class RecipeIngredient {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  recipeId: string;

  @Column()
  ingredientId: string;

  @Column({ type: 'float', default: 1 })
  quantity: number;

  @Column({ default: 'ud' })
  unit: string;

  @Column({ default: false })
  optional: boolean;

  @ManyToOne(() => Recipe, (r) => r.ingredients, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipeId' })
  recipe: Recipe;

  @ManyToOne(() => Ingredient, (i) => i.recipeIngredients, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'ingredientId' })
  ingredient: Ingredient;
}
