import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { Ingredient } from './ingredient.entity';

/** Un ingrediente pendiente de comprar. Al marcarlo "comprado" pasa a la despensa. */
@Entity('shopping_items')
@Unique(['userId', 'ingredientId'])
export class ShoppingItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  ingredientId: string;

  @Column({ type: 'float', default: 1 })
  quantity: number;

  @Column({ default: 'ud' })
  unit: string;

  @Column({ default: false })
  checked: boolean;

  /** Receta que originó la línea (si vino de "añadir faltantes"). */
  @Column({ type: 'varchar', nullable: true })
  recipeId: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Ingredient, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'ingredientId' })
  ingredient: Ingredient;
}
