import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  OneToMany,
  JoinColumn,
  CreateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { RecipeIngredient } from './recipe-ingredient.entity';
import { RecipeStep } from './recipe-step.entity';
import { Like } from './like.entity';
import { Comment } from './comment.entity';
import { SavedRecipe } from './saved-recipe.entity';

@Entity('recipes')
export class Recipe {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  authorId: string;

  @Column()
  title: string;

  @Column({ type: 'text', default: '' })
  description: string;

  @Column({ type: 'varchar', nullable: true })
  photoUrl: string | null;

  @Column({ type: 'int', default: 30 })
  prepMinutes: number;

  @Column({ default: 'Mediterránea' })
  cuisine: string;

  @Column({ type: 'simple-json' })
  dietTags: string[] = [];

  /** Calorías por ración. */
  @Column({ type: 'float', nullable: true })
  calories: number | null;

  /** Macros por ración, en gramos. */
  @Column({ type: 'float', nullable: true })
  protein: number | null;

  @Column({ type: 'float', nullable: true })
  carbs: number | null;

  @Column({ type: 'float', nullable: true })
  fat: number | null;

  @Column({ type: 'int', default: 2 })
  servings: number;

  /** 'fácil' | 'media' | 'difícil' */
  @Column({ default: 'fácil' })
  difficulty: string;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToOne(() => User, (u) => u.recipes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'authorId' })
  author: User;

  @OneToMany(() => RecipeIngredient, (ri) => ri.recipe, { cascade: true })
  ingredients: RecipeIngredient[];

  @OneToMany(() => RecipeStep, (s) => s.recipe, { cascade: true })
  steps: RecipeStep[];

  @OneToMany(() => Like, (l) => l.recipe)
  likes: Like[];

  @OneToMany(() => Comment, (c) => c.recipe)
  comments: Comment[];

  @OneToMany(() => SavedRecipe, (s) => s.recipe)
  saves: SavedRecipe[];
}
