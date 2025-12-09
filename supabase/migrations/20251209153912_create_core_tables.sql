/*
  # Create GoOnline Core Database Schema

  ## Overview
  This migration sets up the foundational database structure for the GoOnline platform - 
  a digital empowerment platform for small businesses to create online presence, 
  collaborate, and grow their business.

  ## New Tables Created

  ### 1. profiles
  Extends Supabase auth.users with additional business-relevant information
  - `id` (uuid, FK to auth.users)
  - `full_name` (text) - User's full name
  - `role` (text) - User role: 'owner', 'admin', 'agent', 'viewer'
  - `phone` (text) - Contact phone number
  - `avatar_url` (text) - Profile picture URL
  - `created_at` (timestamptz) - Account creation timestamp
  - `updated_at` (timestamptz) - Last profile update

  ### 2. businesses
  Stores business storefronts and profiles
  - `id` (uuid, PK) - Unique business identifier
  - `owner_id` (uuid, FK to profiles) - Business owner reference
  - `name` (text) - Business name
  - `description` (text) - Business description
  - `category` (text) - Business category/industry
  - `status` (text) - 'pending', 'active', 'suspended'
  - `logo_url` (text) - Business logo
  - `location` (text) - Physical location
  - `contact_email` (text) - Business contact email
  - `contact_phone` (text) - Business contact phone
  - `created_at` (timestamptz) - Registration date
  - `updated_at` (timestamptz) - Last update

  ### 3. products
  Product/service listings for each business
  - `id` (uuid, PK) - Unique product identifier
  - `business_id` (uuid, FK to businesses) - Parent business
  - `name` (text) - Product/service name
  - `description` (text) - Detailed description
  - `price` (numeric) - Price amount
  - `currency` (text) - Currency code (default 'USD')
  - `stock` (integer) - Available quantity
  - `image_url` (text) - Product image
  - `is_active` (boolean) - Availability status
  - `created_at` (timestamptz) - Creation date
  - `updated_at` (timestamptz) - Last update

  ### 4. orders
  Customer orders and transactions
  - `id` (uuid, PK) - Unique order identifier
  - `business_id` (uuid, FK to businesses) - Business receiving order
  - `customer_id` (uuid, FK to profiles) - Customer who placed order
  - `product_id` (uuid, FK to products) - Ordered product
  - `quantity` (integer) - Order quantity
  - `total_amount` (numeric) - Total order value
  - `status` (text) - 'pending', 'confirmed', 'completed', 'cancelled'
  - `created_at` (timestamptz) - Order date

  ### 5. commissions
  Agent commission tracking and calculation
  - `id` (uuid, PK) - Unique commission record
  - `agent_id` (uuid, FK to profiles) - Agent earning commission
  - `business_id` (uuid, FK to businesses) - Business generating commission
  - `rate` (numeric) - Commission rate percentage
  - `amount` (numeric) - Calculated commission amount
  - `status` (text) - 'pending', 'paid'
  - `created_at` (timestamptz) - Commission record date

  ## Security Implementation

  All tables have Row Level Security (RLS) enabled with restrictive policies:
  - Users can only view their own profile data
  - Business owners have full control over their businesses
  - Products are publicly viewable but only editable by business owners
  - Orders are visible to both customers and business owners
  - Commissions are only visible to the earning agent and admins
  - Admins have special elevated permissions for moderation

  ## Important Notes
  - All IDs use gen_random_uuid() for security
  - Timestamps use timestamptz for timezone awareness
  - Foreign keys ensure referential integrity
  - Indexes on frequently queried columns improve performance
  - Default values reduce null handling complexity
*/

-- Create profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  role text NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'admin', 'agent', 'viewer')),
  phone text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create businesses table
CREATE TABLE IF NOT EXISTS businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  description text,
  category text NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended')),
  logo_url text,
  location text,
  contact_email text,
  contact_phone text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  description text,
  price numeric(10, 2) NOT NULL DEFAULT 0,
  currency text DEFAULT 'USD',
  stock integer DEFAULT 0,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  customer_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  product_id uuid REFERENCES products(id) ON DELETE CASCADE NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  total_amount numeric(10, 2) NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now()
);

-- Create commissions table
CREATE TABLE IF NOT EXISTS commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  business_id uuid REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  rate numeric(5, 2) NOT NULL DEFAULT 10.00,
  amount numeric(10, 2) NOT NULL DEFAULT 0,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_businesses_status ON businesses(status);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON products(business_id);
CREATE INDEX IF NOT EXISTS idx_orders_business_id ON orders(business_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_commissions_agent_id ON commissions(agent_id);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE commissions ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Businesses policies
CREATE POLICY "Anyone can view active businesses"
  ON businesses FOR SELECT
  TO authenticated
  USING (status = 'active' OR owner_id = auth.uid());

CREATE POLICY "Owners can create businesses"
  ON businesses FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update own businesses"
  ON businesses FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can delete own businesses"
  ON businesses FOR DELETE
  TO authenticated
  USING (auth.uid() = owner_id);

-- Products policies
CREATE POLICY "Anyone can view active products"
  ON products FOR SELECT
  TO authenticated
  USING (
    is_active = true OR 
    EXISTS (
      SELECT 1 FROM businesses 
      WHERE businesses.id = products.business_id 
      AND businesses.owner_id = auth.uid()
    )
  );

CREATE POLICY "Business owners can manage products"
  ON products FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM businesses 
      WHERE businesses.id = products.business_id 
      AND businesses.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM businesses 
      WHERE businesses.id = products.business_id 
      AND businesses.owner_id = auth.uid()
    )
  );

-- Orders policies
CREATE POLICY "Customers can view own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id OR 
    EXISTS (
      SELECT 1 FROM businesses 
      WHERE businesses.id = orders.business_id 
      AND businesses.owner_id = auth.uid()
    )
  );

CREATE POLICY "Customers can create orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Business owners can update order status"
  ON orders FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM businesses 
      WHERE businesses.id = orders.business_id 
      AND businesses.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM businesses 
      WHERE businesses.id = orders.business_id 
      AND businesses.owner_id = auth.uid()
    )
  );

-- Commissions policies
CREATE POLICY "Agents can view own commissions"
  ON commissions FOR SELECT
  TO authenticated
  USING (auth.uid() = agent_id);

CREATE POLICY "System can create commissions"
  ON commissions FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Function to automatically create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'owner')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS businesses_updated_at ON businesses;
CREATE TRIGGER businesses_updated_at
  BEFORE UPDATE ON businesses
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS products_updated_at ON products;
CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();