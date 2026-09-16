import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Recipe } from './recipe.entity';

@Entity('recipe_steps')
export class RecipeStep {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  recipeId: string;

  @Column({ type: 'int' })
  position: number;

  @Column({ type: 'text' })
  body: string;

  @ManyToOne(() => Recipe, (r) => r.steps, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipeId' })
  recipe: Recipe;
}
