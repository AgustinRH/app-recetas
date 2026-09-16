import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { PantryItem } from './pantry-item.entity';
import { RecipeIngredient } from './recipe-ingredient.entity';

@Entity('ingredients')
export class Ingredient {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column()
  category: string;

  @Column({ type: 'simple-json' })
  aliases: string[] = [];

  @OneToMany(() => PantryItem, (p) => p.ingredient)
  pantryItems: PantryItem[];

  @OneToMany(() => RecipeIngredient, (ri) => ri.ingredient)
  recipeIngredients: RecipeIngredient[];
}
